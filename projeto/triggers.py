import paho.mqtt.publish as mqtt
import json
import sys

def open_door(origin, destiny):
    message
    print(f"Abrindo porta de {origin} para {destiny}")

def close_door(origin, destiny):
    print(f"Abrindo porta de {origin} para {destiny}")

def open_all_doors():
    print("Abrindo todas as portas")

def close_all_doors():
    print("Fechando todas as portas")

def get_score():
    print("Pontuação: 42")

if __name__ == "__main__":
    command = sys.argv[0]  # tipo da função

    if command == "open_door":
        origin = sys.argv[2]
        destiny = sys.argv[3]
        open_door(origin, destiny)
    elif command == "close_door":
        origin = sys.argv[2]
        destiny = sys.argv[3]
        close_door(origin, destiny)    
    elif command == "open_all_doors":
        open_all_doors()
    elif command == "close_all_doors":
        close_all_doors()
    elif command == "get_score":
        get_score()

# Envia para o broker MQTT
mqtt.single(
    topic="pisid_mazeact",
    payload=json.dumps(message),
    hostname="broker.emqx.io",  # muda se for outro broker
    port=1883
)

print("✅ Mensagem enviada:", message)

