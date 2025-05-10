<?php
$player = $_POST["username"];
$room = $_POST["SalaOrigemController"];

$python = "python";
$script = "/scripts/triggers.py";

$command = escapeshellcmd("$python $script score $player $room");

$output = shell_exec($command);

echo json_encode(["output" => $output]);
