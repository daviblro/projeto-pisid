<?php
header("Access-Control-Allow-Origin: *");
header('Content-Type: application/json');

// Lê o corpo JSON da requisição
$data = json_decode(file_get_contents("php://input"), true);

// Extrai os dados
$email = $data['email'] ?? '';
$password = $data['password'] ?? '';
$idJogo = $data['idJogo'] ?? null;
$nickJogador = $data['nick'] ?? null;

if (!$email || !$password || !$idJogo || !$nickJogador) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Parâmetros incompletos."]);
    exit;
}

// Login com credenciais do utilizador
$conn = new mysqli('localhost', $email, $password, 'pisid_bd9');
if ($conn->connect_error) {
    http_response_code(401);
    echo json_encode(["success" => false, "message" => "Erro de autenticação: " . $conn->connect_error]);
    exit;
}

try {
    $stmt = $conn->prepare("CALL alterar_jogo(?, ?)");
    $stmt->bind_param("is", $idJogo, $nickJogador);
    $stmt->execute();

    echo json_encode(["success" => true, "message" => "Jogo alterado com sucesso."]);
    $stmt->close();
} catch (mysqli_sql_exception $e) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Erro ao alterar jogo: " . $e->getMessage()]);
}

$conn->close();
