import paho.mqtt.client as mqtt
import random
import time

#teste de receção de mensangens de outro pc

mapMarsami =	{ } #marsamis - 15 even / 15 odd
mapMarsami[1] = [0, 2]
mapMarsami[2] = [2,0]

mapSala = [2, 1, 2, 1]

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("Conexão MQTT bem-sucedida!")
    else:
        print("Erro ao conectar ao MQTT. Código de erro:", rc)

def on_message(client, userdata, msg):
    print(f"Mensagem recebida no tópico {msg.topic}: {msg.payload.decode('utf-8')}")
    # room = int(random.random()* 2 + 1) 
    # marsami = int(random.random()* 4) 
    # roomOrigin = mapSala[marsami]
    # if roomOrigin != room:
    #     mapMarsami[room][marsami%2] += 1
    #     mapMarsami[roomOrigin][marsami%2] -= 1
    #     json = {"Player":"9", "Marsami":"2", "RoomOrigin": "roomOrigin", "RoomDestiny": "room", "Status":"1"} 
    #     client.publish("pisid_mazemov_99", json.dumps(json))



client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message
client.connect('broker.emqx.io', 1883)
client.subscribe("pisid_mazemov_9")
client.publish("pisid_mazemov_9", "teste")
# import json
# rooms = []
# while True:
#     room = int(random.random()* 2 + 1) 
#     marsami = int(random.random()* 4) 
#     roomOrigin = mapSala[marsami]
#     if roomOrigin != room:
#         mapMarsami[room][marsami%2] += 1
#         mapMarsami[roomOrigin][marsami%2] -= 1
#         message = {"Player":"9", "Marsami":"2", "RoomOrigin": "roomOrigin", "RoomDestiny": "room", "Status":"1"} 
#         client.publish("pisid_mazemov_99", json.dumps(message))
#         print(mapMarsami)
#     time.sleep(2)

