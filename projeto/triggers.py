import paho.mqtt.publish as mqtt
import paho.mqtt.client as mqtt
import json
import sys
import mysql.connector 
from mysql.connector import Error
import decimal
    
message = None  # Variável global a ser usada para enviar

def open_door(client, player, origin, destiny):
    print(f"Abrindo porta de {origin} para {destiny}")
    client.publish("pisid_mazeact", f"{{Type: OpenDoor, Player:{player}, RoomOrigin: {origin}, RoomDestiny: {destiny}}}")
    

def close_door(client, player, origin, destiny):
    print(f"Fechando porta de {origin} para {destiny}")
    client.publish("pisid_mazeact", f"{{Type: CloseDoor, Player:{player}, RoomOrigin: {origin}, RoomDestiny: {destiny}}}")
    

def open_all_doors(client, player):
    print("Abrindo todas as portas")
    client.publish("pisid_mazeact", f"{{Type: OpenAllDoor, Player:{player}}}")
    

def close_all_doors(client, player):
    print("Fechando todas as portas")
    client.publish("pisid_mazeact", f"{{Type: CloseAllDoor, Player:{player}}}")
    

def score(client,player, room):
    print(f"Disparou na sala {room}")
    client.publish("pisid_mazeact", f"{{Type: Score, Player:{player}}}")
    

def get_score(player):
    try:
        conn = mysql.connector.connect(
            host="localhost",
            user="root",
            password="",
            database="pisid_bd9"
        )
        cursor = conn.cursor(dictionary=True)

        # Obtem o ID do jogo atual do jogador
        cursor.execute("""
            SELECT IDJogo FROM jogo 
            WHERE IDUtilizador = %s AND Estado = 'jogando'
        """, (player,))
        result = cursor.fetchone()

        if not result:
            print(json.dumps({"error": "Jogo não encontrado para o jogador"}))
            return

        jogo_id = result["IDJogo"]

        # Soma total dos pontos das salas associadas ao jogo
        cursor.execute("""
            SELECT SUM(Pontos) as TotalPontos FROM sala
            WHERE IDJogo_Sala = %s
        """, (jogo_id,))
        total = cursor.fetchone()

        # Converter Decimal para int ou float
        pontos = total["TotalPontos"]
        pontos = int(pontos) if pontos is not None else 0

        print(json.dumps({"total_score": pontos}))

    except mysql.connector.Error as e:
        print(json.dumps({"error": str(e)}))
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals() and conn.is_connected():
            conn.close()

    if __name__ == "__main__":
        if len(sys.argv) < 3:
            print("❌ Argumentos insuficientes.")
            sys.exit(1)

        command = sys.argv[1]
        player = sys.argv[2]

        if command == "open_door":
            origin = sys.argv[3]
            destiny = sys.argv[4]
            open_door(client, player, origin, destiny)
        elif command == "close_door":
            origin = sys.argv[3]
            destiny = sys.argv[4]
            close_door(client,  origin, destiny)
        elif command == "open_all_doors":
            open_all_doors(client, player)
        elif command == "close_all_doors":
            close_all_doors(client, player)
        elif command == "score":
            room = sys.argv[3]
            score(client, player, room)
        elif command == "get_score":
            get_score(player)
            sys.exit(0)
        else:
            print("❌ Comando desconhecido.")
            sys.exit(1)

        # Envia para o broker MQTT
        mqtt.single(
            topic="pisid_mazeact",
            payload=str(message),
            hostname="broker.emqx.io", 
            port=1883
        )

client = mqtt.Client(clean_session=True) 
client.subscribe("pisid_mazemov_9", qos=1)
client.connect("broker.emqx.io", 1883, keepalive=30)  # Ping a cada 30s

print("✅ Mensagem enviada:", message)
