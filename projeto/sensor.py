import paho.mqtt.client as mqtt
import json
from pymongo import MongoClient
import re

#recebe através do mqtt e coloca no MongoDB

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
            print("ERRO: Mensagem JSON inválida!", msg)
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
        print("Erro ao processar mensagem:", e)

try:
    clientMongo = MongoClient(
        "mongodb://localhost:27017/",
        serverSelectionTimeoutMS=5000
    )
    mydb = clientMongo["pisid_bd9"]
    mycol_movement = mydb["movement"]
    mycol_sound = mydb["sound"]
    print("MongoDB Connection Successful")
except Exception as e:
    print("Erro ao conectar ao MongoDB:", e)

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
client.on_connect = on_connect
client.on_message = on_message

client.connect("broker.mqtt-dashboard.com", 1883)

client.loop_forever()
