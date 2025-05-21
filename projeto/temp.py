import paho.mqtt.client as mqtt
import json
from pymongo import MongoClient
import re
from mysql.connector import Error
import mysql.connector as mariadb
import sys
from datetime import datetime
import time

def connect_to_mysql():
    try:
        connection = mysql.connector.connect(
            host="localhost",
            user="root",
            password="",
            database="pisid_bd9"
        )
        print("✅ Conectado ao MySQL com sucesso!")
        return connection
    except mysql.connector.Error as err:
        print(f"❌ Erro ao conectar ao MySQL: {err}")
        return None

def on_connect(client, userdata, flags, reason_code):
    print("MQTT conectado com código:", reason_code)
    client.subscribe("pisid_mazemov_9", qos=2)
    client.subscribe("pisid_mazesound_9", qos=2)

def on_message(client, userdata, msg):
    try:
        data = json.loads(msg.payload.decode("utf-8"))
        print(f"📥 Mensagem recebida ({msg.topic}): {data}")
        
    except json.JSONDecodeError:
        print("❌ Erro ao decodificar JSON")    
client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

client.connect('broker.emqx.io', 1883)

# ===== Loop MQTT =====
try:
    print("🚀 A escutar mensagens... Ctrl+C para sair.")
    client.loop_forever()
except KeyboardInterrupt:
    print("\n👋 Encerrando o cliente MQTT...")
    client.disconnect()
 