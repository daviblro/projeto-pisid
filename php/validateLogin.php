<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header('Content-Type: application/json');


// Utilizador de aplicação (limitado)
$dbhost = "localhost";
$dbname = "pisid_bd9";
$dbuser = "fantasma";
$dbpass = "fantasma";

// Recebe os dados (JSON ou POST)
$input = json_decode(file_get_contents("php://input"), true);
if (!$input) {
    $input = $_POST;
}

$email = $input['email'] ?? '';
$password = $input['password'] ?? '';

$response = [
    "success" => false,
    "message" => ""
];

if (empty($email) || empty($password)) {
    $response["message"] = "Campos obrigatórios ausentes.";
    echo json_encode($response);
    exit;
}

// Conecta com utilizador limitado
$conn = new mysqli($dbhost, $dbuser, $dbpass, $dbname);
if ($conn->connect_error) {
    $response["message"] = "Erro ao conectar: " . $conn->connect_error;
    echo json_encode($response);
    exit;
}

// Executa a stored procedure
$stmt = $conn->prepare("CALL validar_login(?, ?)");
$stmt->bind_param("ss", $email, $password);
$stmt->execute();

$result = $stmt->get_result();
$userData = $result->fetch_assoc();

if ($userData) {
    $response["success"] = true;
    $response["message"] = "Login bem-sucedido.";
    $response["user"] = [
        "id" => $userData["IDUtilizador"],
        "nome" => $userData["Nome"],    
        "email" => $userData["Email"]
    ];
} else {
    $response["message"] = "Credenciais inválidas.";
}

$stmt->close();
$conn->close();

echo json_encode($response);