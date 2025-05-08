import paho.mqtt.client as mqtt
import json
from pymongo import MongoClient
import re
from mysql.connector import Error
import mysql.connector as mariadb
import sys
from datetime import datetime
import time

# Obtem o limite de variação passado como argumento --> para fechar as portas depois
sound_threshold = float(sys.argv[1]) if len(sys.argv) > 1 else 10.0  # Valor por defeito: 10.0

'''preliminary

Temos de ver se o algoritmo vai ler cada msg mqtt ou se vamos depois buscar a bd do mongo, nao sei 
qual e o mais rapido  '''    

'''O gatilho é acionado numa certa sala (o número de gatilhos teria de ser menor que 3), 
 o número de gatilhos nessa sala é incrementado, depois é verificado a quantidade de marsamis 
 odd e even, se a quantidade for igual, então os pontos nessa sala são incrementados, se o 
 número de marsamis odd e even não estiverem equilibrados, a sala perde 0.5 pontos.   

Para detectar estes acontecimentos temos de ter um algoritmo, e verificar em que salas os marsamis estão.  

Tal algoritmo baseia-se na utilização de dois ‘Maps’, sendo estes mapMarsami, que mapeia a 
sala em que cada Marsami se encontra (garantindo assim uma verificação extra nos movimentos 
dos Marsamis e aumentando a fiabilidade do algoritmo), e mapSalas, que guarda um tuplo da 
quantidade de Marsamis pares e ímpares em cada sala.    '''

def check_room(room): #tem de ser passado o n' do room
    if mapMarsami[room][0] == mapMarsami[room][1]:
        #dispara gatilho -> atuador -> mandar mensagem para mqtttopic atuador
        print(f'Disparei para a sala {room}! +1 ponto')
 
mapMarsami =	{ }
mapMarsami[0] = [15,15]  #marsamis - 15 even / 15 odd

for i in range(1,10+1):
    mapMarsami[i] = [0,0] 

print(mapMarsami.keys()) #salas
print(f'{mapMarsami.values()} + \n') #n' marsamis
print(mapMarsami)

roomOrigin = 0 #sala 0

#cada vez que chega uma mensagem verificar o n' de marsamis nessa sala

#pisid_ mazeact 9

check_room(roomOrigin)

print(1%2)
print(2%2)

'''
while True:
    # MQTT broker details
    broker = "broker.emqx.io"
    port = 1883
    topic = "pisid_mazeact"

    # Create an MQTT client instance
    client = mqtt.Client()

    # Connect to the broker
    client.connect(broker, port)

    # Publish the message
    result, mid = client.publish(topic, "{Type: Score, Player:9, Room: 2}")

    if result == mqtt.MQTT_ERR_SUCCESS:
        print(f"Message published successfully to topic '{topic}': {{Type: Score, Player:1, Room: 2}}")
    else:
        print(f"Failed to publish message to topic '{topic}' (Result Code: {result})")


'''


 