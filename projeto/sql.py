import paho.mqtt.client as mqtt
import mysql.connector 
from mysql.connector import Error
import json
from datetime import datetime

try:
    connection = mysql.connector.connect(
        host="194.210.86.10",
        user="aluno",
        passwd="aluno",
        db="maze",
        connect_timeout=1000,
        autocommit=True
    )
    print("Connected to MySQL ISCTE Server Sound")
except Error as e:
    print("❌ Erro ao conectar ao MySQL:", e)

cursor = connection.cursor()

cursor.execute("SELECT noisevartoleration, normalnoise FROM SetupMaze")
game_config = cursor.fetchone()
if game_config:
    variation_level = float(game_config[0])
    normal_noise = float(game_config[1])

movement_buffer = []

sound_buffer = []

# ===== Função para conectar ao MySQL (nossa BD)=====
def connect_to_mysql():
    try:
        connection = mysql.connector.connect(
            host="localhost",
            user="root",
            password="",
            database="pisid_bd9"
        )
        print("✅ Conectado ao MySQL com sucesso!")
        return connection
    except mysql.connector.Error as err:
        print(f"❌ Erro ao conectar ao MySQL: {err}")
        return None

# ===== Obter IDJogo do jogo com estado 'jogando' E atualizar limites de som =====
def get_current_game_id(connection):
    try:
        cursor = connection.cursor()
        cursor.execute("SELECT IDJogo FROM jogo WHERE Estado = 'jogando'")
        result = cursor.fetchone()
        if result:
            id_jogo = result[0]

            # Atualizar os campos normalnoise e max_sound do jogo ativo
            max_sound = normal_noise + variation_level
            cursor.execute("""
                UPDATE jogo 
                SET normal_noise = %s, max_sound = %s 
                WHERE IDJogo = %s
            """, (normal_noise, max_sound, id_jogo))
            connection.commit()
            print(f"🔧 Atualizado jogo {id_jogo}: normalnoise={normal_noise}, max_sound={max_sound}")
            
            return id_jogo
        else:
            return None
    except Exception as e:
        print(f"❌ Erro ao obter/atualizar IDJogo: {e}")
        return None
    
def insert_into_mysql_from_buffer(connection, table, data, id_jogo):
    cursor = connection.cursor()
    try:
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
            
        if table == "movement":
            print(f'{data} from buffer FROM BUFFER')
            query = "INSERT INTO movement (Marsami, RoomOrigin, RoomDestiny, IDJogo, Status) VALUES (%s, %s, %s, %s, %s)"
            values = (data["Marsami"], data["RoomOrigin"], data["RoomDestiny"], id_jogo, data["Status"])
            cursor.execute(query, values)
            connection.commit()

            if "gatilho" in data:
                print("gatilho em data")
                print(data["gatilho"])
                for room in data["gatilho"]:
                    if room != 0:
                            cursor.execute("""
                            UPDATE sala 
                            SET Gatilhos = Gatilhos + 1, Pontos = Pontos + 1
                            WHERE IDSala = %s and IDJogo_Sala = %s
                        """, (room, id_jogo))
                            
        elif table == "sound":
                    sound_value = float(data["Sound"])
                    query = "INSERT INTO sound (IDJogo, Hour, Sound) VALUES (%s, %s, %s)"
                    values = (id_jogo, data["Hour"], sound_value)
                    cursor.execute(query, values)
                    connection.commit()
                    print(f"✅ Dados inseridos na tabela {table} com sucesso! from buffer FROM BUFFER")

                    '''# Verificar limiares
                    ruido_normal = 19.0
                    tolerancia_maxima = 2.5'''
                    limite_max = normal_noise + variation_level

                    aviso_threshold = normal_noise + 0.75 * variation_level               # 20.875
                    perigo_threshold = normal_noise + 0.90 * variation_level              # 21.25
                    '''aviso_threshold = 19.25 #teste
                    perigo_threshold =19.3 #teste'''

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
                            WHERE IDJogo = %s
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
                                #client.publish("pisid_mazeact", f"{{Type: CloseAllDoor, Player:9}}")
                            elif segundos_desde_ultimo > 5:
                                permitir_insercao = True
                                #client.publish("pisid_mazeact", f"{{Type: OpenAllDoor, Player:9}}")

                        if permitir_insercao: 
                            cursor.execute("""
                                INSERT INTO mensagens (Hora, Leitura, TipoAlerta, Msg, IDJogo)
                                VALUES (%s, %s, %s, %s, %s)
                            """, (data["Hour"], sound_value, alerta, mensagem, id_jogo))
                            connection.commit()
                            print(f"🚨 Alerta '{alerta}' registado na tabela mensagens! from buffer FROM BUFFER")
                        else:
                            print(f"⏱️ Alerta '{alerta}' ignorado (cooldown ativo ou repetido).")
    except Exception as e:
        print(f"❌ Erro ao inserir dados no MySQL: {e}")
        
# ===== Inserir dados =====
def insert_into_mysql(connection, table, data):
    global movement_buffer
    global sound_buffer
    
    print(movement_buffer)

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
        
    if not connection:
        print("SEM CONEXAO SQL")
        if table == "movement":
            movement_buffer.append(json.dumps(data))
            print("Inseri no buffer")
        elif table == "sound":
            sound_buffer.append(json.dumps(data))
    else:
        try:
            id_jogo = get_current_game_id(connection)
            if not id_jogo:
                print("⚠️ Nenhum jogo ativo encontrado.")
                return
            
            cursor = connection.cursor()
            print("📦 Dados recebidos:", data)
            
            if len(movement_buffer) > 0:
                print("TEM MOVIMENTOS NO BUFFER")
                for i in range(len(movement_buffer)):
                    message = json.loads(movement_buffer.pop(0))
                    insert_into_mysql_from_buffer(connection, "movement", message, id_jogo)

            if len(sound_buffer) > 0:
                for i in range(len(sound_buffer)):
                    message = json.loads(sound_buffer.pop(0))
                    insert_into_mysql_from_buffer(connection, "sound", message, id_jogo)

            if table == "movement":
                print(data)
                query = "INSERT INTO movement (Marsami, RoomOrigin, RoomDestiny, IDJogo, Status) VALUES (%s, %s, %s, %s, %s)"
                values = (data["Marsami"], data["RoomOrigin"], data["RoomDestiny"], id_jogo, data["Status"])
                cursor.execute(query, values)
                connection.commit()

                if "gatilho" in data:
                    print("gatilho em data")
                    print(data["gatilho"])
                    for room in data["gatilho"]:
                        if room != 0:
                                cursor.execute("""
                                UPDATE sala 
                                SET Gatilhos = Gatilhos + 1, Pontos = Pontos + 1
                                WHERE IDSala = %s and IDJogo_Sala = %s
                            """, (room, id_jogo))

                print(f"✅ Dados inseridos na tabela {table} com sucesso!")

            elif table == "sound":
                sound_value = float(data["Sound"])
                query = "INSERT INTO sound (IDJogo, Hour, Sound) VALUES (%s, %s, %s)"
                values = (id_jogo, data["Hour"], sound_value)
                cursor.execute(query, values)
                connection.commit()
                print(f"✅ Dados inseridos na tabela {table} com sucesso!")

                '''# Verificar limiares
                ruido_normal = 19.0
                tolerancia_maxima = 2.5'''
                limite_max = normal_noise + variation_level

                aviso_threshold = normal_noise + 0.75 * variation_level               # 20.875
                perigo_threshold = normal_noise + 0.90 * variation_level              # 21.25
                '''aviso_threshold = 19.25 #teste
                perigo_threshold =19.3 #teste'''

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
                        WHERE IDJogo = %s
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
                            #client.publish("pisid_mazeact", f"{{Type: CloseAllDoor, Player:9}}")
                        elif segundos_desde_ultimo > 5:
                            permitir_insercao = True
                            #client.publish("pisid_mazeact", f"{{Type: OpenAllDoor, Player:9}}")

                    if permitir_insercao: 
                        cursor.execute("""
                            INSERT INTO mensagens (Hora, Leitura, TipoAlerta, Msg, IDJogo)
                            VALUES (%s, %s, %s, %s, %s)
                        """, (data["Hour"], sound_value, alerta, mensagem, id_jogo))
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
        client.subscribe("pisid_mazemov_99", qos=2)
        client.subscribe("pisid_mazesound_99", qos=2)
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
        
        if not (client.mysql_connection and client.mysql_connection.is_connected()):
            print("TRYING TO CONNECT TO SQL")
            client.mysql_connection = connect_to_mysql()

        for message in data["messages"]:
            if "Player" not in message:
                print("❌ Chave 'Player' ausente!")
                continue

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
