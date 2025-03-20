import paho.mqtt.client as mqtt
from pymongo import MongoClient
import json
import threading
import os
import time

#conecta o mongo e publish mqtt 

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
client.connect('broker.mqtt-dashboard.com', 1883)
client.loop_start()  # Inicia a thread MQTT em background

# 📂 Carregar IDs já enviados de um ficheiro (evita reenvios após restart)
sent_ids_file = "sent_ids.json"
if os.path.exists(sent_ids_file):
    with open(sent_ids_file, "r") as f:
        sent_ids = set(json.load(f))  # Carrega os IDs enviados
else:
    sent_ids = set()

def save_sent_ids():
    """Guarda os IDs enviados no ficheiro."""    
    with open(sent_ids_file, "w") as f:
        json.dump(list(sent_ids), f)

def send_mqtt_messages():
    while True:
        try:
            # 🔍 Enviar Movimentos em Batch
            movements = []
            for x in mycol_movement.find({}, {"_id": 1, "Player": 1, "Marsami": 1, "RoomOrigin": 1, "RoomDestiny": 1, "Status": 1}):  
                message_id = str(x["_id"])  # Converte _id para string
                if message_id not in sent_ids:
                    x["_id"] = message_id  # Converte o próprio _id para string na mensagem
                    movements.append(x)  # Adiciona a mensagem para envio
                    sent_ids.add(message_id)  # Regista como enviada

            if movements:
                batch_message = json.dumps({"messages": movements})
                client.publish("pisid_mazemov_99", batch_message)
                print(f"📤 Enviados {len(movements)} movimentos em batch.")
                save_sent_ids()  # Atualiza o ficheiro

            # 🔊 Enviar Sons em Batch
            sounds = []
            for x in mycol_sound.find({}, {"_id": 1, "Player": 1, "Hour": 1, "Sound": 1}):  
                message_id = str(x["_id"])  # Converte _id para string
                if message_id not in sent_ids:
                    x["_id"] = message_id  # Converte o próprio _id para string na mensagem
                    sounds.append(x)  # Adiciona a mensagem para envio
                    sent_ids.add(message_id)  # Regista como enviada

            if sounds:
                batch_message = json.dumps({"messages": sounds})
                client.publish("pisid_mazesound_99", batch_message)
                print(f"📤 Enviados {len(sounds)} sons em batch.")
                save_sent_ids()  # Atualiza o ficheiro

        except Exception as e:
            print("❌ Erro ao enviar mensagens MQTT:", e)

        # Espera antes de verificar novamente (evita alto consumo de CPU)
        time.sleep(2)

print("🎧 A escutar mensagens recebidas... Pressione Ctrl+C para sair.")
try:
    send_mqtt_messages()
except KeyboardInterrupt:
    print("🔴 Finalizando...")
    client.loop_stop()
    client.disconnect()
    clientMongo.close()
