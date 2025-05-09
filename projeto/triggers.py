import paho.mqtt.publish as mqtt
import json
import sys

message = None  # Variável global a ser usada para enviar

def open_door(player, origin, destiny):
    print(f"Abrindo porta de {origin} para {destiny}")
    return {
        f"{{Type: OpenDoor, Player: {player}, RoomOrigin: {origin}, RoomDestiny: {destiny}}}"
    }

def close_door(player, origin, destiny):
    print(f"Fechando porta de {origin} para {destiny}")
    return {
        f"{{Type: CloseDoor, Player: {player}, RoomOrigin: {origin}, RoomDestiny: {destiny}}}"
    }

def open_all_doors(player):
    print("Abrindo todas as portas")
    return {
        f"{{Type: OpenAllDoor, Player: {player}}}"
    }

def close_all_doors(player):
    print("Fechando todas as portas")
    return {
        f"{{Type: CloseAllDoor, Player: {player}}}"
    }

def score(player, room):
    print(f"Disparou na sala {room}")
    return {
       f"{{Type: Score, Player: {player}}}"
    }

def get_score(player):
    print(f"Pedido de pontuação do jogador {player}")
    return {
        ""
    }

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("❌ Argumentos insuficientes.")
        sys.exit(1)

    command = sys.argv[1]
    player = sys.argv[2]

    if command == "open_door":
        origin = sys.argv[3]
        destiny = sys.argv[4]
        message = open_door(player, origin, destiny)
    elif command == "close_door":
        origin = sys.argv[3]
        destiny = sys.argv[4]
        message = close_door(player, origin, destiny)
    elif command == "open_all_doors":
        message = open_all_doors(player)
    elif command == "close_all_doors":
        message = close_all_doors(player)
    elif command == "score":
        room = sys.argv[3]
        message = score(player, room)
    elif command == "get_score":
        message = get_score(player)
    else:
        print("❌ Comando desconhecido.")
        sys.exit(1)

    # Envia para o broker MQTT
    mqtt.single(
        topic="pisid_mazeact",
        payload=message,
        hostname="broker.emqx.io", 
        port=1883
    )

    print("✅ Mensagem enviada:", message)
