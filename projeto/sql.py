import paho.mqtt.client as mqtt
import mysql.connector
import json

# ===== Função para conectar ao MySQL =====
def connect_to_mysql():
    try:
        connection = mysql.connector.connect(
            host="localhost",
            user="root",
            password="",
            database="pisid"
        )
        print("✅ Conectado ao MySQL com sucesso!")
        create_tables_if_not_exist(connection)
        return connection
    except mysql.connector.Error as err:
        print(f"❌ Erro ao conectar ao MySQL: {err}")
        return None

# ===== Criar tabelas se não existirem =====
def create_tables_if_not_exist(connection):
    try:
        cursor = connection.cursor()
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS movement (
                id INT AUTO_INCREMENT PRIMARY KEY,
                Player VARCHAR(255) NOT NULL,
                Marsami BOOLEAN NOT NULL,
                RoomOrigin INT NOT NULL,
                RoomDestiny INT NOT NULL,
                Status VARCHAR(255) NOT NULL,
                Timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS sound (
                id INT AUTO_INCREMENT PRIMARY KEY,
                Player VARCHAR(255) NOT NULL,
                Hour DATETIME NOT NULL,
                Sound FLOAT NOT NULL,
                Timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)

        connection.commit()
        print("🛠️ Tabelas verificadas/criadas com sucesso!")
    except Exception as e:
        print(f"❌ Erro ao criar/verificar tabelas: {e}")

# ===== Inserir dados =====
def insert_into_mysql(connection, table, data):
    try:
        cursor = connection.cursor()

        print("📦 Dados recebidos:", data)

        if table == "movement":
            required_keys = ["Player", "Marsami", "RoomOrigin", "RoomDestiny", "Status"]
        elif table == "sound":
            required_keys = ["Player", "Hour", "Sound"]
        else:
            print("❌ Tabela desconhecida")
            return

        for key in required_keys:
            if key not in data:
                print(f"❌ Erro: Chave {key} ausente nos dados!")
                return

        if table == "movement":
            query = "INSERT INTO movement (Player, Marsami, RoomOrigin, RoomDestiny, Status) VALUES (%s, %s, %s, %s, %s)"
            values = (data["Player"], data["Marsami"], data["RoomOrigin"], data["RoomDestiny"], data["Status"])

        elif table == "sound":
            query = "INSERT INTO sound (Player, Hour, Sound) VALUES (%s, %s, %s)"
            values = (data["Player"], data["Hour"], data["Sound"])

        cursor.execute(query, values)
        connection.commit()
        print(f"✅ Dados inseridos na tabela {table} com sucesso!")
    except Exception as e:
        print(f"❌ Erro ao inserir dados no MySQL: {e}")

# ===== Callback MQTT - Conexão =====
def on_connect(client, userdata, flags, reason_code):
    if reason_code == 0:
        print("📡 Conexão MQTT bem-sucedida!")
        client.subscribe("pisid_mazemov_99")
        client.subscribe("pisid_mazesound_99")
        client.mysql_connection = connect_to_mysql()
    else:
        print(f"❌ Erro ao conectar ao MQTT. Código: {reason_code}")

# ===== Callback MQTT - Mensagem =====
def on_message(client, userdata, msg):
    try:
        data = json.loads(msg.payload.decode("utf-8"))
        print(f"📥 Mensagem recebida ({msg.topic}): {data}")
        
        if "messages" not in data:
            print("❌ Campo 'messages' ausente!")
            return
        
        for message in data["messages"]:
            if "Player" not in message:
                print("❌ Chave 'Player' ausente!")
                continue
            
            if client.mysql_connection:
                if msg.topic == "pisid_mazemov_99":
                    insert_into_mysql(client.mysql_connection, "movement", message)
                elif msg.topic == "pisid_mazesound_99":
                    insert_into_mysql(client.mysql_connection, "sound", message)
    except json.JSONDecodeError:
        print("❌ Erro ao decodificar JSON")

# ===== Setup MQTT =====
client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

client.connect('broker.emqx.io', 1883)

# ===== Loop MQTT =====
try:
    print("🚀 A escutar mensagens... Ctrl+C para sair.")
    client.loop_forever()
except KeyboardInterrupt:
    print("\n👋 Encerrando o cliente MQTT...")
    client.disconnect()
