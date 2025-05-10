<?php
header("Access-Control-Allow-Origin: *");
header('Content-Type: application/json');

// Lê o corpo JSON da requisição
$data = json_decode(file_get_contents("php://input"), true);

$email = $data['email'] ?? '';
$password = $data['password'] ?? '';
$nickJogador = $data['nome'] ?? '';  // vem do campo "nome"

if (!$email || !$password || !$nickJogador) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Parâmetros incompletos."]);
    exit;
}

// Conecta com as credenciais do utilizador
$conn = new mysqli('localhost', $email, $password, 'pisid_bd9');
if ($conn->connect_error) {
    http_response_code(401);
    echo json_encode(["success" => false, "message" => "Erro de autenticação: " . $conn->connect_error]);
    exit;
}

try {
    $stmt = $conn->prepare("CALL criar_jogo(?)");
    $stmt->bind_param("s", $nickJogador);
    $stmt->execute();

    $result = $stmt->get_result();
    $msg = $result ? $result->fetch_assoc() : null;

    echo json_encode(["success" => true, "message" => $msg['Mensagem'] ?? 'Jogo criado com sucesso!']);
    $stmt->close();
} catch (mysqli_sql_exception $e) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Erro ao criar jogo: " . $e->getMessage()]);
}

$conn->close();
