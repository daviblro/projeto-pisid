<?php
header("Access-Control-Allow-Origin: *");
header('Content-Type: application/json');

// Lê os dados JSON do corpo
$data = json_decode(file_get_contents("php://input"), true);

$email = $data['email'] ?? '';
$password = $data['password'] ?? '';

if (!$email || !$password) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Credenciais não fornecidas."]);
    exit;
}

$conn = new mysqli('localhost', $email, $password, 'pisid_bd9');
if ($conn->connect_error) {
    http_response_code(401);
    echo json_encode(["success" => false, "message" => "Erro de autenticação."]);
    exit;
}

try {
    $stmt = $conn->prepare("CALL get_jogos()");
    $stmt->execute();
    $result = $stmt->get_result();

    $jogos = [];
    while ($row = $result->fetch_assoc()) {
        $jogos[] = $row;
    }

    echo json_encode(["success" => true, "jogos" => $jogos]);

    $stmt->close();
} catch (mysqli_sql_exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Erro ao buscar jogos: " . $e->getMessage()]);
}

$conn->close();
