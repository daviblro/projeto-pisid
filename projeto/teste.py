import paho.mqtt.client as mqtt

#teste de receção de mensangens de outro pc

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("Conexão MQTT bem-sucedida!")
    else:
        print("Erro ao conectar ao MQTT. Código de erro:", rc)

def on_message(client, userdata, msg):
    print(f"Mensagem recebida no tópico {msg.topic}: {msg.payload.decode('utf-8')}")

client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message
client.connect('broker.emqx.io', 1883)
client.subscribe("pisid_mazemov_99")
client.subscribe("pisid_mazesound_99")

print("A escutar mensagens recebidas... Pressione Ctrl+C para sair.")
client.loop_forever()
