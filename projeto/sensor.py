import paho.mqtt.client as mqtt
import json
from pymongo import MongoClient
import re
from mysql.connector import Error
import mysql.connector as mariadb
import sys

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

def insert_game_config(cursor, playerNumber):
  
    try:
        # 1. Obter os corredores
        sql_corridor = "SELECT RoomA, RoomB FROM Corridor;"
        cursor.execute(sql_corridor)
        records = cursor.fetchall()

        room_map = {}

        for row in records:
            room_a = int(row[0])
            room_b = int(row[1])

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
            print("❌ ERRO: Mensagem JSON inválida!", msg)
            return None

def on_connect(client, userdata, flags, reason_code, properties):
    print("Connected with result code", str(reason_code))
    client.subscribe("pisid_mazemov_9")
    client.subscribe("pisid_mazesound_9")

def on_message(client, userdata, msg):
    try:
        decoded_message = msg.payload.decode("utf-8")
        print(f"Mensagem recebida no tópico {msg.topic}: {decoded_message}")

        # Corrige e valida o JSON
        message = fix_json_format(decoded_message)
        if message:
            if msg.topic == "pisid_mazemov_9":
                mycol_movement.insert_one(message)
                print("Movimento guardado no MongoDB!")
            elif msg.topic == "pisid_mazesound_9":
                mycol_sound.insert_one(message)
                print("Som guardado no MongoDB!")

    except Exception as e:
        print(f"❌ Erro ao processar mensagem: {e}")

# Conectar ao MySQL e inserir a configuração do jogo
connection = connect_to_mysql()
if connection:
    cursor = connection.cursor()

    if len(sys.argv) == 2: 
        playerNumber = int(sys.argv[1])#nao seria necessari se nao for preciso especificar qual o player
        insert_game_config(cursor, playerNumber)

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
client.on_connect = on_connect
client.on_message = on_message

client.connect("broker.emqx.io", 1883)

client.loop_forever()