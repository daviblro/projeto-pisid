import paho.mqtt.publish as mqtt
import json
import sys
import mysql.connector 
from mysql.connector import Error

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
            WHERE IDJogador = %s AND Estado = 'jogando'
        """, (player,))
        result = cursor.fetchone()

        if not result:
            print(json.dumps({"error": "Jogo não encontrado para o jogador"}))
            return

        jogo_id = result["IDJogo"]

        # Obtem pontuações das salas desse jogo
        cursor.execute("""
            SELECT IDSala, Pontos FROM sala
            WHERE IDJogo_Sala = %s
        """, (jogo_id,))
        salas = cursor.fetchall()

        print(json.dumps({"scores": salas}))  # Output que o PHP vai apanhar

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
        get_score(player)
        sys.exit(0)
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
