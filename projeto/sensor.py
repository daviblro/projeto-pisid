import paho.mqtt.client as mqtt
import json
from pymongo import MongoClient
import re
from mysql.connector import Error
import mysql.connector as mariadb
import sys
from datetime import datetime
import time

# Obtem o limite de variação passado como argumento para ser outlier
sound_threshold = float(sys.argv[1]) if len(sys.argv) > 1 else 10.0  # Valor por defeito: 10.0

#Configuração do mapa
mapMarsami =	{ }
mapMarsami[0] = [15,15]  #marsamis - 15 even / 15 odd
for i in range(1,10+1):
    mapMarsami[i] = [0,0] 
gatilho = [0 for i in range(1,11)]

closeDoorSound = 0
check_closed_door = False

def check_room(room, client): #tem de ser passado o n' do room
    global gatilho
    global mapMarsami
    if(gatilho[room-1] >= 3):
        return False
    
    print(mapMarsami)
    if (mapMarsami[room][0] != mapMarsami[room][1] and mapMarsami[room][0] > 1):   #n é necessário verificação de sala nula porque é sempre visto uma sala com algum marsami
        client.publish("pisid_mazeact", f"{{Type: Score, Player:9, Room: {room}}}")
        gatilho[room-1] += 1
        print(f"Sala {room}: {mapMarsami[room][0]} even e {mapMarsami[room][1]} odd")
        print(f'Disparei para a sala {room}! +1 ponto')
        return True
    return False    

# Funções de validação
def is_valid_datetime(dt_str, message):
    try:
        datetime.fromisoformat(dt_str)
        return True
    except ValueError:
        print(f"Data inválida: Hour='{dt_str}'")
        mycol_dados.insert_one({
            "type": "invalid_date",
            "document": message,
            "reason": "Invalid datetime format"
        })
        return False

def validate_required_fields(data, required_fields, tipo_msg):
    missing_fields = [field for field in required_fields if field not in data]
    if missing_fields:
        print(f"❌ Campos obrigatórios em falta: {missing_fields}")
        mycol_dados.insert_one({
            "type": f"missing_fields_{tipo_msg}",
            "document": data,
            "reason": f"Missing required fields: {missing_fields}"
        })
        return False
    return True

# Conexão com MongoDB
try:
    clientMongo = MongoClient("mongodb://localhost:27017/", serverSelectionTimeoutMS=5000)
    mydb = clientMongo["pisid_bd9"]
    mycol_movement = mydb["movement"]
    mycol_sound = mydb["sound"]
    mycol_dados = mydb["dados_invalidos"]
    mycol_game = mydb["game_configs"]
    print("✅ Conexão sucedida MongoDB")
except Exception as e:
    print("❌ Erro ao conectar ao MongoDB:", e)
    exit()

def connect_to_mysql():
    try:
        connection = mariadb.connect(
            host="194.210.86.10",
            user="aluno",
            passwd="aluno",
            db="maze",
            connect_timeout=1000,
            autocommit=True
        )
        print("Connected to MySQL ISCTE Server Sound")
        return connection
    except Error as e:
        print("❌ Erro ao conectar ao MySQL:", e)
        return None
    

def insert_game_config(cursor):
    try:
        cursor.execute("SELECT RoomA, RoomB FROM Corridor;")
        records = cursor.fetchall()

        room_map = {}
        for room_a, room_b in records:
            room_map.setdefault(room_a, []).append(room_b)
            room_map.setdefault(room_b, []).append(room_a)

        rooms_config = [{"roomId": rid, "connectedTo": sorted(set(conns))} for rid, conns in room_map.items()]

        cursor.execute("SELECT noisevartoleration, normalnoise FROM SetupMaze")
        game_config = cursor.fetchone()

        if game_config:
            variation_level = float(game_config[0])
            normal_noise = float(game_config[1])
            global closeDoorSound 
            closeDoorSound = normal_noise + 0.9 * variation_level
            config_json = {
                "NormalNoise": normal_noise,
                "soundVariationLimit": variation_level,
                "roomsConfig": rooms_config
            }
            mycol_game.insert_one(config_json)
            print("✅ Configuração do jogo inserida no MongoDB com sucesso!")
    except Exception as e:
        print("❌ Erro ao obter dados do jogo:", e)

def fix_json_format(msg):
    try:
        return json.loads(msg)
    except json.JSONDecodeError:
        try:
            msg = re.sub(r'(\w+):', r'"\1":', msg)
            msg = re.sub(r'(\d{4}-\d{2}-\d{2})\s*"(\d{2})":"(\d{2})":', r'\1 \2:\3:', msg)
            return json.loads(msg)
        except json.JSONDecodeError:
            print("❌ JSON inválido:", msg)
            mycol_dados.insert_one({
                "type": "invalid_json",
                "document": msg,
                "reason": "Could not parse JSON"
            })
            return None

def on_connect(client, userdata, flags, reason_code):
    print("MQTT conectado com código:", reason_code)
    client.subscribe("pisid_mazemov_9", qos=1)
    client.subscribe("pisid_mazesound_9", qos=1)

def on_message(client, userdata, msg):
    try:
        decoded_message = msg.payload.decode("utf-8")
        print(f"Mensagem recebida no tópico {msg.topic}: {decoded_message}")

        message = fix_json_format(decoded_message)
        if not message:
            return

        if msg.topic == "pisid_mazemov_9":
            global mapMarsami
            required_fields = ["Player", "Marsami", "RoomOrigin", "RoomDestiny", "Status"]
            if not validate_required_fields(message, required_fields, "movement"):
                return
            
                        # Ignora verificação de configuração se RoomOrigin for 0
            if message["RoomOrigin"] == 0:
                mapMarsami[message["RoomDestiny"]][message["Marsami"]%2] += 1
                mycol_movement.insert_one(message)
                print("✅ Movimento com RoomOrigin=0 guardado no MongoDB!")
                return

            dados_cursor = mycol_game.find_one({
                "roomsConfig": {
                    "$elemMatch": {"roomId": message["RoomOrigin"]}
                }
            })

            if dados_cursor is None:
                print(f"❌ Movimento inválido - RoomOrigin={message['RoomOrigin']} sem configuração.")
                mycol_dados.insert_one({
                    "type": "invalid_movement",
                    "document": message,
                    "reason": "RoomOrigin sem configuração"
                })
                return

            connected = next(
                (r["connectedTo"] for r in dados_cursor["roomsConfig"] if r["roomId"] == message["RoomOrigin"]),
                []
            )

            if message["RoomDestiny"] not in connected:
                print("❌ Dado inválido - destino não está ligado à origem.")
                mycol_dados.insert_one({
                    "type": "invalid_connection",
                    "document": message,
                    "reason": "RoomDestiny not connected to RoomOrigin"
                })
            else:
                if(mapMarsami[message["RoomOrigin"]][message["Marsami"]%2] > 0):
                    mapMarsami[message["RoomOrigin"]][message["Marsami"]%2] -= 1
                mapMarsami[message["RoomDestiny"]][message["Marsami"]%2] += 1

                trigger_rooms = [0, 0]
                if check_room(message["RoomDestiny"], client):
                    trigger_rooms[message["RoomDestiny"]%2] = message["RoomDestiny"]
                if check_room(message["RoomOrigin"], client):
                    trigger_rooms[message["RoomOrigin"]%2] = message["RoomOrigin"]

                if trigger_rooms[0] != 0 or trigger_rooms[1] != 0:
                    message["gatilho"] = trigger_rooms

                mycol_movement.insert_one(message)
                print("✅ Movimento guardado no MongoDB!")

        elif msg.topic == "pisid_mazesound_9":
            if not validate_required_fields(message, ["Player", "Hour", "Sound"], "sound"):
                return

            hour = message.get("Hour")
            sound_value = message["Sound"]

            if not is_valid_datetime(hour, message):
                return

            is_outlier = False
            last_sounds = list(mycol_sound.find(
                {"Player": message["Player"]}
            ).sort("Hour", -1).limit(1))
            
            if last_sounds:
                previous_sound = last_sounds[0]["Sound"]
                variation = abs(sound_value - previous_sound)
                if variation > sound_threshold:
                    is_outlier = True
                    print("⚠️ OUTLIER DETECTADO")
                    mycol_dados.insert_one({
                        "type": "outlier",
                        "document": message,
                        "reason": f"Variação de som excede limite ({variation:.2f} > {sound_threshold})"
                    })

            if not (18 < sound_value < 30):
                print(f"Som inválido: Sound='{sound_value}'")
                mycol_dados.insert_one({
                    "type": "invalid_sound",
                    "document": message,
                    "reason": "Som fora do intervalo permitido (18-30)"
                })
                return

            global check_closed_door

            if not is_outlier:
                print("Som válido: A verificar se é crítico")
                print(f"Som atual: {message["Sound"]}, Som Critico: {closeDoorSound}")
                if message["Sound"] >= closeDoorSound :
                    client.publish("pisid_mazeact", f"{{Type: CloseAllDoor, Player:9}}")
                    print("❌❌Som crítico: A FECHAR❌❌❌")

                elif check_closed_door and message["Sound"] < closeDoorSound*0.98:
                    client.publish("pisid_mazeact", f"{{Type: OpenAllDoor, Player:9}}")
                    print("✅✅✅✅✅Som bom: ABRIR")
                    check_closed_door = False

                mycol_sound.insert_one(message)
                print("✅ Som guardado no MongoDB!")

    except Exception as e:
        print(f"❌ Erro ao processar mensagem: {e}")

connection = connect_to_mysql()
if connection:
    cursor = connection.cursor()
    insert_game_config(cursor)


client = mqtt.Client(clean_session=True) 
client.on_connect = on_connect
client.on_message = on_message
client.connect("broker.emqx.io", 1883, keepalive=30)  # Ping a cada 30s
client.loop_forever()