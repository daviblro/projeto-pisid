<?php
header("Access-Control-Allow-Origin: *");
header('Content-Type: application/json');

// Caminho completo para o arquivo .bat
$batPath = "C:\\xampp\\htdocs\\iniciar.bat";

// Garante que o caminho está corretamente escapado
$escapedPath = escapeshellarg($batPath);

// Usa `popen` com `start` para abrir janelas CMD
popen("start \"\" $escapedPath", "r");

// Retorna resposta simples de sucesso
echo json_encode([
    "success" => true,
    "message" => "Scripts e executável iniciados em janelas CMD."
]);
