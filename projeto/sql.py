import paho.mqtt.client as mqtt
import mysql.connector
import json

# Função para conectar ao MySQL
def connect_to_mysql():
    try:
        connection = mysql.connector.connect(
            host="localhost",
            user="root",
            password="",
            database="maze"
        )
        print("Conectado ao MySQL com sucesso!")
        return connection
    except mysql.connector.Error as err:
        print(f"Erro ao conectar ao MySQL: {err}")
        return None

# Função para inserir dados na base de dados MySQL
def insert_into_mysql(connection, table, data):
    try:
        cursor = connection.cursor()

        print("Dados recebidos:", data)

        if table == "movement":
            required_keys = ["Player", "Marsami", "RoomOrigin", "RoomDestiny", "Status"]
        elif table == "sound":
            required_keys = ["Player", "Hour", "Sound"]
        else:
            print("Tabela desconhecida")
            return

        for key in required_keys:
            if key not in data:
                print(f"Erro: Chave {key} ausente nos dados!")
                return

        if table == "movement":
            query = "INSERT INTO movement (Player, Marsami, RoomOrigin, RoomDestiny, Status) VALUES (%s, %s, %s, %s, %s)"
            values = (data["Player"], data["Marsami"], data["RoomOrigin"], data["RoomDestiny"], data["Status"])

        elif table == "sound": #abaixo, esta adicionar o campo IDJogo ao sound
            ''' 
           {{ search_query = """
                SELECT IDJogo FROM jogo
                WHERE utilizador_id = %s AND %s BETWEEN DataHoraInicio AND DataHoraFim
                ORDER BY DataHoraInicio DESC
                LIMIT 1
            """
            cursor.execute(search_query, (data["Player"], data["Hour"]))
            result = cursor.fetchone()

            if result is None:
                print("Nenhum jogo encontrado para esse jogador e hora.")
                return

            IDJogo = result[0]

            query = "INSERT INTO sound (Player, Hour, Sound, IDJogo) VALUES (%s, %s, %s, %s)"
            values = (data["Player"], data["Hour"], data["Sound"], IDJogo)}}
            '''


            query = "INSERT INTO sound (Player, Hour, Sound) VALUES (%s, %s, %s)"
            values = (data["Player"], data["Hour"], data["Sound"])

        cursor.execute(query, values)
        connection.commit()
        print(f"Dados inseridos na tabela {table} com sucesso!")
    except Exception as e:
        print(f"Erro ao inserir dados no MySQL: {e}")

# Função chamada quando o cliente MQTT se conecta
def on_connect(client, userdata, flags, reason_code):
    if reason_code == 0:
        print("Conexão MQTT bem-sucedida!")
        client.subscribe("pisid_mazemov_99")
        client.subscribe("pisid_mazesound_99")
        client.mysql_connection = connect_to_mysql()
        if client.mysql_connection:
            print("Conexão MySQL bem-sucedida!")
    else:
        print(f"Erro ao conectar ao MQTT. Código de erro: {reason_code}")

# Função chamada quando uma mensagem MQTT é recebida
def on_message(client, userdata, msg):
    try:
        data = json.loads(msg.payload.decode("utf-8"))
        print(f"Mensagem recebida no tópico {msg.topic}: {data}")
        
        if "messages" not in data:
            print("Erro: Campo 'messages' ausente nos dados!")
            return
        
        for message in data["messages"]:
            if "Player" not in message:
                print("Erro: Chave 'Player' ausente nos dados!")
                continue
            
            if client.mysql_connection:
                if msg.topic == "pisid_mazemov_99":
                    insert_into_mysql(client.mysql_connection, "movement", message)
                elif msg.topic == "pisid_mazesound_99":
                    insert_into_mysql(client.mysql_connection, "sound", message)
    except json.JSONDecodeError:
        print("Erro ao decodificar JSON")

# Configuração do cliente MQTT com a nova API
client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

# Conectar ao broker MQTT
client.connect('broker.emqx.io', 1883)

# Iniciar o loop do MQTT
try:
    print("A escutar mensagens recebidas... Pressione Ctrl+C para sair.")
    client.loop_forever()
except KeyboardInterrupt:
    print("\nEncerrando o cliente MQTT...")
    client.disconnect()
