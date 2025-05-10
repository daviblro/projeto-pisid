<?php
$player = $_POST["username"];
$origin = $_POST["SalaOrigemController"];
$destiny = $_POST["SalaDestinoController"];

$python = "python";
$script = "/scripts/triggers.py";

$command = escapeshellcmd("$python $script close_door $player $origin $destiny");

$output = shell_exec($command);

echo json_encode(["output" => $output]);
