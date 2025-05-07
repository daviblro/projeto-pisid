import paho.mqtt.client as mqtt
import json
from pymongo import MongoClient
import re
from mysql.connector import Error
import mysql.connector as mariadb
import sys
from datetime import datetime

# Obtem o limite de variação passado como argumento para ser outlier
sound_threshold = float(sys.argv[1]) if len(sys.argv) > 1 else 10.0  # Valor por defeito: 10.0

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
            config_json = {
                "maxSoundLevel": normal_noise,
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

def on_connect(client, userdata, flags, reason_code, properties):
    print("MQTT conectado com código:", reason_code)
    client.subscribe("pisid_mazemov_9", qos=2)
    client.subscribe("pisid_mazesound_9", qos=2)

def on_message(client, userdata, msg):
    try:
        decoded_message = msg.payload.decode("utf-8")
        print(f"Mensagem recebida no tópico {msg.topic}: {decoded_message}")

        message = fix_json_format(decoded_message)
        if not message:
            return

        if msg.topic == "pisid_mazemov_9":
            required_fields = ["Player", "Marsami", "RoomOrigin", "RoomDestiny", "Status"]
            if not validate_required_fields(message, required_fields, "movement"):
                return
            
                        # Ignora verificação de configuração se RoomOrigin for 0
            if message["RoomOrigin"] == 0:
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

            if not is_outlier:
                mycol_sound.insert_one(message)
                print("✅ Som guardado no MongoDB!")

    except Exception as e:
        print(f"❌ Erro ao processar mensagem: {e}")

connection = connect_to_mysql()
if connection:
    cursor = connection.cursor()
    insert_game_config(cursor)

client = mqtt.Client(callback_api_version=mqtt.CallbackAPIVersion.VERSION2)
client.on_connect = on_connect
client.on_message = on_message
client.connect("broker.emqx.io", 1883)
client.loop_forever()
