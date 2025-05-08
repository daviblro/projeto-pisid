<?php
	$db = "pisid_bd9";
	$dbhost = "localhost";
	$username = $_POST["username"];
	$password = $_POST["password"];

    $conn = mysqli_connect($dbhost,$username,$password,$db);
	
	$sql = "
		SELECT Msg, Leitura, TipoAlerta, Hora, HoraEscrita
		FROM mensagens
		WHERE Hora >= now() - interval 60 minute
		ORDER BY Hora DESC
	";
	
	$response["mensagens"] = array();
	$result = mysqli_query($conn, $sql);	
	if ($result){
		if (mysqli_num_rows($result)>0){		
			while($r=mysqli_fetch_assoc($result)){	
				try {	
					$ad = array();
					$ad["Msg"] = $r['Msg'];				
					$ad["Leitura"] = $r['Leitura'];			
					$ad["TipoAlerta"] = $r['TipoAlerta'];
					$ad["Hora"] = $r['Hora'];
					$ad["HoraEscrita"] = $r['HoraEscrita'];
				array_push($response["mensagens"], $ad);			
				}
				catch (Exception $e) {echo ($e);}
			}
		}
	}
	header('Content-Type: application/json');
	// tell browser that its a json data
	echo json_encode($response);
	//converting array to JSON string
?>