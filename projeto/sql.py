import paho.mqtt.client as mqtt
import mysql.connector
import json
from datetime import datetime

# ===== Função para conectar ao MySQL =====
def connect_to_mysql():
    try:
        connection = mysql.connector.connect(
            host="localhost",
            user="root",
            password="",
            database="pisid_bd9"
        )
        print("✅ Conectado ao MySQL com sucesso!")
        create_tables_if_not_exist(connection)
        return connection
    except mysql.connector.Error as err:
        print(f"❌ Erro ao conectar ao MySQL: {err}")
        return None

# ===== Obter IDJogo do jogo com estado 'jogando' =====
def get_current_game_id(connection):
    try:
        cursor = connection.cursor()
        cursor.execute("SELECT IDJogo FROM jogo WHERE Estado = 'jogando'")
        result = cursor.fetchone()
        return result[0] if result else None
    except Exception as e:
        print(f"❌ Erro ao obter IDJogo: {e}")
        return None

# ===== Criar tabelas se não existirem =====
def create_tables_if_not_exist(connection):
    try:
        cursor = connection.cursor()

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS movement (
                IDMovement INT AUTO_INCREMENT PRIMARY KEY,
                Marsami VARCHAR(50) NOT NULL,
                RoomOrigin VARCHAR(50) NOT NULL,
                RoomDestiny VARCHAR(50) NOT NULL,
                IDJogo INT NOT NULL,
                Status VARCHAR(50) NOT NULL
            )
        """)

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS sound (
                IDSound INT AUTO_INCREMENT PRIMARY KEY,
                IDJogo INT NOT NULL,
                Hour DATETIME NOT NULL,
                Sound FLOAT NOT NULL
            )
        """)

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS mensagens (
                IDMensagem INT AUTO_INCREMENT PRIMARY KEY,
                HoraEscrita TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                Sensor INT,
                Leitura DECIMAL(10,2),
                TipoAlerta VARCHAR(50),
                Msg VARCHAR(100),
                IDJogo INT NOT NULL,
                Hora TimeStamp
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
            required_keys = ["Marsami", "RoomOrigin", "RoomDestiny", "Status"]
        elif table == "sound":
            required_keys = ["Hour", "Sound"]
        else:
            print("❌ Tabela desconhecida")
            return

        for key in required_keys:
            if key not in data:
                print(f"❌ Erro: Chave {key} ausente nos dados!")
                return

        id_jogo = get_current_game_id(connection)
        if not id_jogo:
            print("⚠️ Nenhum jogo ativo encontrado.")
            return

        if table == "movement":
            query = "INSERT INTO movement (Marsami, RoomOrigin, RoomDestiny, IDJogo, Status) VALUES (%s, %s, %s, %s, %s)"
            values = (data["Marsami"], data["RoomOrigin"], data["RoomDestiny"], id_jogo, data["Status"])
            cursor.execute(query, values)
            connection.commit()
            print(f"✅ Dados inseridos na tabela {table} com sucesso!")

        elif table == "sound":
            sound_value = float(data["Sound"])
            query = "INSERT INTO sound (IDJogo, Hour, Sound) VALUES (%s, %s, %s)"
            values = (id_jogo, data["Hour"], sound_value)
            cursor.execute(query, values)
            connection.commit()
            print(f"✅ Dados inseridos na tabela {table} com sucesso!")

            # Verificar limiares
            ruido_normal = 19.0
            tolerancia_maxima = 2.5
            limite_max = ruido_normal + tolerancia_maxima

            #aviso_threshold = ruido_normal + 0.50 * tolerancia_maxima  # 21.25
            #perigo_threshold = ruido_normal + 0.75 * tolerancia_maxima  # 21.375
            aviso_threshold = 19.25 #teste
            perigo_threshold =19.3 #teste

            alerta = None
            mensagem = None

            if sound_value >= perigo_threshold:
                alerta = "Perigo_Ruido"
                mensagem = f"⚠️ Som crítico: {sound_value:.2f} dB (≥95% do limite de {limite_max})"
            elif sound_value >= aviso_threshold:
                alerta = "Aviso_Ruido"
                mensagem = f"🔔 Som elevado: {sound_value:.2f} dB (≥90% do limite de {limite_max})"

            if alerta:
                cursor.execute("""
                    SELECT TipoAlerta, HoraEscrita FROM mensagens
                    WHERE Sensor = %s
                    ORDER BY Hora DESC LIMIT 1
                """, (id_jogo,))
                resultado = cursor.fetchone()

                permitir_insercao = False

                if not resultado:
                    permitir_insercao = True
                else:
                    ultimo_tipo, ultima_hora = resultado
                    segundos_desde_ultimo = (datetime.now() - ultima_hora).total_seconds()

                    if alerta == "Perigo_Ruido" and ultimo_tipo != "Perigo_Ruido":
                        permitir_insercao = True
                    elif segundos_desde_ultimo > 5:
                        permitir_insercao = True

                if permitir_insercao:
                    cursor.execute("""
                        INSERT INTO mensagens (Hora, Sensor, Leitura, TipoAlerta, Msg, IDJogo)
                        VALUES (%s, %s, %s, %s, %s, %s)
                    """, (data["Hour"], id_jogo, sound_value, alerta, mensagem, id_jogo))
                    connection.commit()
                    print(f"🚨 Alerta '{alerta}' registado na tabela mensagens!")
                else:
                    print(f"⏱️ Alerta '{alerta}' ignorado (cooldown ativo ou repetido).")

    except Exception as e:
        print(f"❌ Erro ao inserir dados no MySQL: {e}")

# ===== Callback MQTT - Conexão =====
def on_connect(client, userdata, flags, reason_code):
    if reason_code == 0:
        print("📡 Conexão MQTT bem-sucedida!")
        client.subscribe("pisid_mazemov_99", qos=1)
        client.subscribe("pisid_mazesound_99", qos=1)
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
