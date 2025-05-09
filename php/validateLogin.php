<?php
header("Access-Control-Allow-Origin: http://127.0.0.1:3000");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header('Content-Type: application/json');
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
$dbname = "pisid_bd9";
$dbhost = "localhost";

// Utilizador interno para SELECT
$internalUser = "root";
$internalPass = ""; // Ajusta para tua password do MySQL

// Lê os dados JSON enviados no corpo da requisição
$input = json_decode(file_get_contents("php://input"), true);

$username = $input['email'] ?? '';
$password = $input['password'] ?? '';

$response = [
    "success" => false,
    "message" => " $username, $password"
];
echo json_encode($response);

$response = [
    "success" => false,
    "message" => ""
];

// Verifica se os campos foram enviados
if (empty($username) || empty($password)) {
    //$response["message"] = "Campos de login ausentes.";
    //echo json_encode($response);
    exit;
}

// 1. Tenta conectar com as credenciais do utilizador
$conn = @mysqli_connect($dbhost, $username, $password, $dbname);

if ($conn) {
    mysqli_close($conn); // Login OK, fecha conexão

    // 2. Conecta com utilizador interno para buscar info
    $internalConn = @mysqli_connect($dbhost, $internalUser, $internalPass, $dbname);
    
    if (!$internalConn) {
        //$response["message"] = "Erro interno ao obter dados do utilizador.";
        //echo json_encode($response);
        exit;
    }

    // 3. Buscar dados do utilizador pela tabela
    $stmt = $internalConn->prepare("SELECT IDUtilizador, Nome FROM utilizador WHERE Email = ?");
    $stmt->bind_param("s", $username);
    $stmt->execute();
    $result = $stmt->get_result();
    $userData = $result->fetch_assoc();

    if ($userData) {
        $response["success"] = true;
        $response["message"] = "Login bem-sucedido.";
        $response["user"] = [
            "id" => $userData["IDUtilizador"],
            "nome" => $userData["Nome"],
            "email" => $username
        ];
    } else {
        $response["message"] = "Utilizador não encontrado na tabela.";
    }

    $stmt->close();
    $internalConn->close();
} else {
    $response["message"] = "Login falhou. Verifique email e senha.";
}

//echo json_encode($response);
?>
