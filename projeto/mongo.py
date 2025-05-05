import paho.mqtt.client as mqtt
from pymongo import MongoClient
import json
import threading
import time
from bson.objectid import ObjectId
from datetime import datetime

#envia as mensagens do PC1 para PC2, Mongo -> MQTT

# Conectar ao MongoDB
try:
    clientMongo = MongoClient("mongodb://localhost:27017/", serverSelectionTimeoutMS=5000)
    mydb = clientMongo["pisid_bd9"]
    mycol_movement = mydb["movement"]
    mycol_sound = mydb["sound"]
    mycol_dados = mydb["dados_invalidos"]
    print("✅ Conexão sucedida MongoDB")
except Exception as e:
    print("❌ Erro ao conectar ao MongoDB:", e)
    exit()

# MQTT Configuração
client = mqtt.Client(callback_api_version=2)
client.connect('broker.emqx.io', 1883)
client.loop_start()


# Função para validar datas
def is_valid_datetime(dt_str):
    try:
        # Tenta converter a string para datetime 
        datetime.fromisoformat(dt_str)
        return True
    except ValueError:
        return False

def is_valid_sound(sound):
    if (sound > 18 and sound < 30):
        return True
    return False

    

def send_mqtt_messages():
    while True:
        try:
            # 🔍 Enviar movimentos não enviados (sent != True)
            movements_cursor = mycol_movement.find({"sent": {"$ne": True}}, 
                                                   {"_id": 1, "Player": 1, "Marsami": 1, "RoomOrigin": 1, "RoomDestiny": 1, "Status": 1})
            movements = list(movements_cursor)

            for m in movements:
                m["_id"] = str(m["_id"])
                
            if movements:
                batch_message = json.dumps({"messages": movements})
                client.publish("pisid_mazemov_99", batch_message, qos=1)
                print(f"📤 Enviados {len(movements)} movimentos em batch.")

                # Atualiza os documentos como enviados
                ids = [m["_id"] for m in movements]
                mycol_movement.update_many(
                    {"_id": {"$in": [ObjectId(id) for id in ids]}},
                    {"$set": {"sent": True}}
                )

            # 🔊 Enviar sons não enviados
            sounds_cursor = mycol_sound.find({"sent": {"$ne": True}}, 
                                             {"_id": 1, "Player": 1, "Hour": 1, "Sound": 1})
            sounds = list(sounds_cursor)
         
            for s in sounds:
                s["_id"] = str(s["_id"])

            if sounds:
                batch_message = json.dumps({"messages": sounds})
                client.publish("pisid_mazesound_99", batch_message, qos=1)
                print(f"📤 Enviados {len(sounds)} sons em batch.")

                # Atualiza os documentos como enviados
                ids = [s["_id"] for s in sounds]
                mycol_sound.update_many(
                    {"_id": {"$in": [ObjectId(id) for id in ids]}},
                    {"$set": {"sent": True}}
                )

        except Exception as e:
            print("❌ Erro ao enviar mensagens MQTT:", e)

        #time.sleep(2)

from bson.objectid import ObjectId  # <- necessário para o update_many

print("🎧 A escutar mensagens recebidas... Pressione Ctrl+C para sair.")
try:
    send_mqtt_messages()
except KeyboardInterrupt:
    print("🔴 Finalizando...")
    client.loop_stop()
    client.disconnect()
    clientMongo.close()
