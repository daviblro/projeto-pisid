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
    print(json.dumps({"Abriu a porta": origin}))

    

def close_door(client, player, origin, destiny):
    print(f"Fechando porta de {origin} para {destiny}")
    client.publish("pisid_mazeact", f"{{Type: CloseDoor, Player:{player}, RoomOrigin: {origin}, RoomDestiny: {destiny}}}")
    print(json.dumps({"Fechou a porta": destiny }))

    

def open_all_doors(client, player):
    print("Abrindo todas as portas")
    client.publish("pisid_mazeact", f"{{Type: OpenAllDoor, Player:{player}}}")
    print(json.dumps({"Abriu todas as portas"}))

    

def close_all_doors(client, player):
    print("Fechando todas as portas")
    client.publish("pisid_mazeact", f"{{Type: CloseAllDoor, Player:{player}}}")
    print(json.dumps({"Fechou todas as portas"}))


def score(client, player, room):
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

        # Verifica o número de gatilhos acionados na sala
        cursor.execute("""
            SELECT Gatilhos FROM sala
            WHERE IDJogo_Sala = %s AND IDSala = %s
        """, (jogo_id, room))
        gatilho_result = cursor.fetchone()

        if not gatilho_result:
            print(json.dumps({"error": "Sala não encontrada"}))
            return

        gatilhos = gatilho_result["Gatilhos"] or 0

        if gatilhos >= 3:
            print(json.dumps({"error": f"Sala {room} já acionou os 3 gatilhos"}))
            return

        # Envia a mensagem MQTT
        print(f"Disparou na sala {room}")
        client.publish("pisid_mazeact", f"{{Type: Score, Player:{player}}}")
        print(json.dumps({"Disparou na sala": room}))

        # Incrementa o número de gatilhos da sala
        cursor.execute("""
            UPDATE sala
            SET Gatilhos = IFNULL(Gatilhos, 0) + 1
            WHERE IDJogo_Sala = %s AND IDSala = %s
        """, (jogo_id, room))
        conn.commit()

    except mysql.connector.Error as e:
        print(json.dumps({"error": str(e)}))
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals() and conn.is_connected():
            conn.close()


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

client = mqtt.Client(clean_session=True) 
client.connect("broker.emqx.io", 1883, keepalive=30)  # Ping a cada 30s

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
            close_door(client, player, origin, destiny)
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

print("✅ Mensagem enviada:", message)
