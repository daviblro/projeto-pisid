import paho.mqtt.client as mqtt
import json
from pymongo import MongoClient
import re
from mysql.connector import Error
import mysql.connector as mariadb
import sys
from datetime import datetime

#código que lê do sensor e coloca na base de dados do mongo tudo, MQTT -> Mongo

def is_valid_datetime(dt_str, message):
    try:
        # Tenta converter a string para datetime 
        datetime.fromisoformat(dt_str)
        return True
    except ValueError:
        print(f"Data inválida detectada em documento -> Hour='{dt_str}'")
        mycol_dados.insert_one({
        "type": "invalid_date",
        "document": message,
        "reason": "Invalid datetime format"
        })
        return False

    

def is_valid_sound(sound, message):
    if (sound > 18 and sound < 30):
        return True
    
    print(f"Som inválido detectado em documento -> Hour='{message["Sound"]}'")
    mycol_dados.insert_one({
        "type": "invalid_sound",
        "document": message,
        "reason": "Inválido sound"
    })               
    return False

def validate_required_fields(data, required_fields, tipo_msg):
    missing_fields = [field for field in required_fields if field not in data]
    if missing_fields:
        print(f"❌ Erro: Campos obrigatórios em falta ({missing_fields}) na mensagem.")
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

# MQTT Configuração
client = mqtt.Client(callback_api_version=2)
client.connect('broker.emqx.io', 1883)
client.loop_start()

def connect_to_mysql():
    usermysqliscte = "aluno"
    passmysqliscte = "aluno"
    hostiscte = "194.210.86.10"
    databasemysql = "maze"

    try:
        connection = mariadb.connect(
            host=hostiscte,
            user=usermysqliscte,
            passwd=passmysqliscte,
            db=databasemysql,
            connect_timeout=1000,
            autocommit=True
        )
        print("Connected to MySQL ISCTE Server Sound")
    except Error as e:
        print("❌ Error while connecting to MySQL ISCTE Server Sound", e)
        return None

    return connection

def insert_game_config(cursor):
  
    try:
        # 1. Obter os corredores
        sql_corridor = "SELECT RoomA, RoomB FROM Corridor;"
        cursor.execute(sql_corridor)
        records = cursor.fetchall()

        room_map = {}

        for row in records:
            room_a = int(row[0])
            room_b = int(row[1])
            print(room_a)
            print(room_b)

            # Adiciona conexões para RoomA
            if room_a not in room_map:
                room_map[room_a] = []
            if room_b not in room_map[room_a]:
                room_map[room_a].append(room_b)

            # Adiciona conexões para RoomB (bi-direcional)
            if room_b not in room_map:
                room_map[room_b] = []
            if room_a not in room_map[room_b]:
                room_map[room_b].append(room_a)

        rooms_config = [{"roomId": rid, "connectedTo": sorted(conns)} for rid, conns in room_map.items()]

        # 2. Obter os valores de variação e limite de som
        cursor.execute("SELECT noisevartoleration, normalnoise FROM SetupMaze") #Se for preciso especificar o player, é por WHERE Player = %s", (playerNumber,)), e por tambem nas salas
        game_config = cursor.fetchone()

        if game_config:
            variation_level = float(game_config[0])
            normal_noise = float(game_config[1])

            config_json = {
                "maxSoundLevel": normal_noise,
                "soundVariationLimit": variation_level,
                "roomsConfig": rooms_config
            }

            # Inserir no MongoDB
            mycol_game.insert_one(config_json)
            print("✅ Configuração do jogo inserida no MongoDB com sucesso!")
        else:
            print(f"⚠️ Nenhuma configuração de jogo encontrada para o jogador {playerNumber}")

    except Exception as e:
        print(f"❌ Erro ao obter dados do jogo: {e}")

def fix_json_format(msg):
    try:
        return json.loads(msg)  # Tenta converter diretamente
    except json.JSONDecodeError:
        try:
            # Corrige chaves JSON sem aspas
            msg = re.sub(r'(\w+):', r'"\1":', msg)

            # Corrige formato da hora
            msg = re.sub(r'(\d{4}-\d{2}-\d{2})\s*"(\d{2})":"(\d{2})":', r'\1 \2:\3:', msg)

            return json.loads(msg)  # Tenta novamente
        except json.JSONDecodeError:
            print("❌ JSON inválido:", msg)
            mycol_dados.insert_one({
                "type": "invalid_json",
                "document": msg,
                "reason": "Could not parse JSON"
            })
            return None

def on_connect(client, userdata, flags, reason_code, properties):
    print("Connected with result code", str(reason_code))
    client.subscribe("pisid_mazemov_9")
    client.subscribe("pisid_mazesound_9")

def on_message(client, userdata, msg):
    try:
        decoded_message = msg.payload.decode("utf-8")
        print(f"Mensagem recebida no tópico {msg.topic}: {decoded_message}")

        # Corrige e valida o 
        message = fix_json_format(decoded_message)
        if message:
            if msg.topic == "pisid_mazemov_9":                
                # Buscar a configuração da sala de origem
 
                required_fields = ["Player", "Marsami", "RoomOrigin", "RoomDestiny", "Status"]
                if not validate_required_fields(message, required_fields, "movement"):
                    return
                else:
                    if message["RoomOrigin"] == 0:
                        pass
                    else:

                        dados_cursor = mycol_game.find_one({
                            "roomsConfig": {
                                "$elemMatch": {
                                    "roomId": message["RoomOrigin"]
                                }
                            }
                        })

                        if dados_cursor is None:
                            print(f"⚠️ Configuração não encontrada para RoomOrigin={message['RoomOrigin']}")
                            mycol_dados.insert_one({
                                "type": "missing_config",
                                "document": message,
                                "reason": "RoomOrigin not found in config"
                            })

                        connected = next(
                            (r["connectedTo"] for r in dados_cursor["roomsConfig"] if r["roomId"] == message["RoomOrigin"]),
                            []
                        )
                        
                        if message["RoomDestiny"] not in connected:
                            print("Dado inválido - destino não está ligado à origem.")
                            mycol_dados.insert_one({
                                "type": "invalid_connection",
                                "document": message,
                                "reason": "RoomDestiny not connected to RoomOrigin"
                            })
                        if(outlier):
                            pass ##codigo for outlier    
                        else: 
                            mycol_movement.insert_one(message)
                            print("Movimento guardado no MongoDB!")

            elif msg.topic == "pisid_mazesound_9":
                if not validate_required_fields(message, ["Player", "Hour", "Sound"], "sound"):
                    pass
                
                hour = message.get("Hour")
                if(is_valid_sound(message["Sound"], message) and is_valid_datetime(hour, message)):
                    mycol_sound.insert_one(message)
                    print("Som guardado no MongoDB!")
                
                if(outlier):
                    pass ##codigo for outlier
                else:
                    print("Som errado SOM ERRADO")
                    

    except Exception as e:
        print(f"❌ Erro ao processar mensagem: {e}")

# Conectar ao MySQL e inserir a configuração do jogo
connection = connect_to_mysql()
if connection:
    cursor = connection.cursor()

    if len(sys.argv) == 1: 
        insert_game_config(cursor)

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
client.on_connect = on_connect
client.on_message = on_message

client.connect("broker.emqx.io", 1883)

client.loop_forever()