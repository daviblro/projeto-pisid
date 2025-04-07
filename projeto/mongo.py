import paho.mqtt.client as mqtt
from pymongo import MongoClient
import json
import threading
import time
from bson.objectid import ObjectId
from datetime import datetime

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


def send_mqtt_messages():
    while True:
        try:
            # 🔍 Enviar movimentos não enviados (sent != True)
            movements_cursor = mycol_movement.find({"sent": {"$ne": True}}, 
                                                   {"_id": 1, "Player": 1, "Marsami": 1, "RoomOrigin": 1, "RoomDestiny": 1, "Status": 1})
            movements = list(movements_cursor)
            for m in movements:
                m["_id"] = str(m["_id"])  # Converte o ID para string (para envio)

                if m["RoomOrigin"] == 0:
                    continue  # Ignora movimentos com RoomOrigin = 0

                # Buscar a configuração da sala de origem
                dados_cursor = mydb["game_configs"].find_one({
                    "roomsConfig": {
                        "$elemMatch": {
                            "roomId": m["RoomOrigin"]
                        }
                    }
                })

                if dados_cursor is None:
                    print(f"⚠️ Configuração não encontrada para RoomOrigin={m['RoomOrigin']}")
                    mycol_dados.insert_one({
                        "type": "missing_config",
                        "document": m,
                        "reason": "RoomOrigin not found in config"
                    })
                    continue  # Salta este movimento

                connected = next(
                    (r["connectedTo"] for r in dados_cursor["roomsConfig"] if r["roomId"] == m["RoomOrigin"]),
                    []
                )
                
                if m["RoomDestiny"] not in connected:
                    print("Dado inválido - destino não está ligado à origem.")
                    mycol_dados.insert_one({
                        "type": "invalid_connection",
                        "document": m,
                        "reason": "RoomDestiny not connected to RoomOrigin"
                    })
                    continue  # Também salta este movimento

            valid_movements = [m for m in movements if "sent" not in m or not m["sent"]]
            if valid_movements:
                batch_message = json.dumps({"messages": valid_movements})
                client.publish("pisid_mazemov_99", batch_message)
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
            valid_sounds = []
            for s in sounds:
                s["_id"] = str(s["_id"])
                hour = s.get("Hour")
                if isinstance(hour, str) and is_valid_datetime(hour):
                    valid_sounds.append(s)
                else:
                    print(f"Data inválida detectada em documento _id={s['_id']} -> Hour='{hour}'")
                    mycol_dados.insert_one({
                        "type": "invalid_date",
                        "document": s,
                        "reason": "Invalid datetime format"
                    })

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

        time.sleep(2)

from bson.objectid import ObjectId  # <- necessário para o update_many

print("🎧 A escutar mensagens recebidas... Pressione Ctrl+C para sair.")
try:
    send_mqtt_messages()
except KeyboardInterrupt:
    print("🔴 Finalizando...")
    client.loop_stop()
    client.disconnect()
    clientMongo.close()
