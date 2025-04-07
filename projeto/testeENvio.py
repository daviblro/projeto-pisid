import paho.mqtt.client as mqtt
from pymongo import MongoClient
import json
import threading
import time

# Conectar ao MongoDB
try:
    clientMongo = MongoClient("mongodb://localhost:27017/", serverSelectionTimeoutMS=5000)
    mydb = clientMongo["pisid_bd9"]
    mycol_movement = mydb["movement"]
    mycol_sound = mydb["sound"]
    print("✅ Conexão sucedida MongoDB")
except Exception as e:
    print("❌ Erro ao conectar ao MongoDB:", e)
    exit()

# MQTT Configuração
client = mqtt.Client(callback_api_version=2)
client.connect('broker.emqx.io', 1883)
client.loop_start()

def send_mqtt_messages():
    i=0
    while True:
        try:
            client.publish("pisid_mazemov_99", payload=f"{i}", qos=1)
            print(f"📤 Enviei {i}.")
        except Exception as e:
            print("❌ Erro ao enviar mensagens MQTT:", e)
        i+=1
        time.sleep(0.1)


print("🎧 A escutar mensagens recebidas... Pressione Ctrl+C para sair.")
try:
    send_mqtt_messages()
except KeyboardInterrupt:
    print("🔴 Finalizando...")
    client.loop_stop()
    client.disconnect()
    clientMongo.close()
