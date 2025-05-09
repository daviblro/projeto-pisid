import paho.mqtt.client as mqtt
import json
from pymongo import MongoClient
import re
from mysql.connector import Error
import mysql.connector as mariadb
import sys
from datetime import datetime
import time

client = mqtt.Client() 
client.connect("broker.emqx.io", 1883)
start = datetime.now()
rest = start
while(True):
    client.publish("pisid_mazeact", f"{{Type: Score, Player:9, Room: {6}}}")
    now = datetime.now()
    print(f"Comecei às {start} e agora são {now}")
    print(f"Intervalo de {now - rest}")
    rest = datetime.now()
    time.sleep(0.25)
    
    
    
