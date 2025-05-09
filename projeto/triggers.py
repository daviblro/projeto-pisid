import paho.mqtt.publish as publish
import json
import sys

# Argumentos: Type, Player, (RoomOrigin), (RoomDestiny), (Room)
args = sys.argv[1:]

if len(args) < 2:
    print("❌ Argumentos insuficientes")
    sys.exit(1)

action_type = args[0]
player = int(args[1])
message = {"Type": action_type, "Player": player}

if action_type in ["OpenDoor", "CloseDoor"]:
    message["RoomOrigin"] = int(args[2])
    message["RoomDestiny"] = int(args[3])
elif action_type == "Score":
    message["Room"] = int(args[2])
elif action_type in ["OpenAllDoor", "CloseAllDoor"]:
    pass  # Só precisa do tipo e player
else:
    print("❌ Tipo inválido")
    sys.exit(1)

# Envia para o broker MQTT
publish.single(
    topic="pisid_mazeact",
    payload=json.dumps(message),
    hostname="broker.emqx.io",  # muda se for outro broker
    port=1883
)

print("✅ Mensagem enviada:", message)
