<?php
header("Access-Control-Allow-Origin: *");
header('Content-Type: application/json');

// Lê o corpo da requisição
$data = json_decode(file_get_contents("php://input"), true);
$idJogo = $data['idJogo'] ?? null;
$email = $data['email'] ?? null;
$password = $data['password'] ?? null;

if (!$idJogo || !$email || !$password) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Dados incompletos."]);
    exit;
}

// Conecta com as credenciais do utilizador
$conn = new mysqli('localhost', $email, $password, 'pisid_bd9');
if ($conn->connect_error) {
    http_response_code(401);
    echo json_encode(["success" => false, "message" => "Erro de autenticação."]);
    exit;
}

try {
    $stmt = $conn->prepare("CALL getIdJogo_IdUtilizador()");
    $stmt->execute();
    $result = $stmt->get_result();

    $jogo = $result->fetch_assoc();
    echo json_encode(["success" => true, "nick" => $jogo['NickJogador'] ?? '']);

    $stmt->close();
} catch (mysqli_sql_exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Erro ao obter jogo: " . $e->getMessage()]);
}

$conn->close();
