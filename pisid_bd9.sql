-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: May 10, 2025 at 11:25 AM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `pisid_bd9`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `alterar_jogo` (IN `p_idjogo` INT, IN `p_NickJogador` VARCHAR(50))   BEGIN
    DECLARE v_id_utilizador INT;
    DECLARE v_email VARCHAR(50);

    SET v_email = SUBSTRING_INDEX(USER(), '@', 2);

    SELECT IDUtilizador INTO v_id_utilizador
    FROM utilizador
    WHERE Email = v_email;

    IF EXISTS (
        SELECT 1 FROM jogo
        WHERE IDJogo = p_idjogo
        AND Estado != 'jogando'
        AND IDUtilizador = v_id_utilizador
    ) THEN
        UPDATE jogo
        SET NickJogador = p_NickJogador
        WHERE IDJogo = p_idjogo;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Você não tem permissão para alterar este jogo.';
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `alterar_utilizador` (IN `p_emailAntigo` VARCHAR(50), IN `p_emailNovo` VARCHAR(50), IN `p_NomeNovo` VARCHAR(100), IN `p_TelemovelNovo` VARCHAR(12), IN `p_GrupoNovo` INT, IN `p_SenhaNovaOpcional` VARCHAR(100))   BEGIN
    DECLARE v_email_antigo VARCHAR(50);
    DECLARE v_IDUtilizador INT;
    DECLARE sql_query VARCHAR(1000);

    SET v_email_antigo = p_emailAntigo;

    SELECT IDUtilizador INTO v_IDUtilizador
    FROM utilizador
    WHERE Email = v_email_antigo;

    IF p_emailNovo IS NOT NULL AND p_emailNovo != '' AND TRIM(p_emailNovo) != TRIM(v_email_antigo) THEN
        -- Atualiza dados e email
        UPDATE utilizador
        SET Telemovel = p_TelemovelNovo,
            Grupo = p_GrupoNovo,
            Nome = p_NomeNovo,
            Email = p_emailNovo
        WHERE IDUtilizador = v_IDUtilizador;

        -- Renomeia o utilizador do sistema
        SET sql_query = CONCAT('RENAME USER ''', v_email_antigo, '''@''localhost'' TO ''', p_emailNovo, '''@''localhost'';');
        PREPARE stmt FROM sql_query;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        -- Atualiza email antigo para o novo
        SET v_email_antigo = p_emailNovo;
    ELSE
        -- Só atualiza os restantes dados (sem mexer no email)
        UPDATE utilizador
        SET Telemovel = p_TelemovelNovo,
            Grupo = p_GrupoNovo,
            Nome = p_NomeNovo
        WHERE IDUtilizador = v_IDUtilizador;
    END IF;

    -- Se a senha foi passada, altera também
    IF p_SenhaNovaOpcional IS NOT NULL AND p_SenhaNovaOpcional != '' THEN
        SET sql_query = CONCAT('ALTER USER ''', v_email_antigo, '''@''localhost'' IDENTIFIED BY ''', p_SenhaNovaOpcional, ''';');
        PREPARE stmt FROM sql_query;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `criar_jogo` (IN `p_nick_jogador` VARCHAR(50))   BEGIN
    DECLARE v_id_utilizador INT;
    DECLARE v_email VARCHAR(50);

	SET v_email = SUBSTRING_INDEX(USER(), '@', 2);
    
    -- Tenta obter o ID do utilizador
    SELECT IDUtilizador INTO v_id_utilizador
    FROM utilizador
    WHERE Email = v_email;
        
    -- Se não encontrou nenhum ID, dá erro (mas tratamos o erro com CONTINUE HANDLER)
    IF v_id_utilizador IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Utilizador não encontrado com o email do utilizador atual.';
    ELSE
        -- Inserir o novo jogo
        INSERT INTO jogo (
            NickJogador,
            Estado,
            IDUtilizador
        )
        VALUES (
            p_nick_jogador,
            'nao_inicializado',
            v_id_utilizador
        );

        -- Mensagem de sucesso
        SELECT 'Jogo criado com sucesso!' AS Mensagem;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `criar_utilizador` (IN `p_email` VARCHAR(50), IN `p_nome` VARCHAR(100), IN `p_telemovel` VARCHAR(12), IN `p_tipo` VARCHAR(20), IN `p_grupo` INT, IN `p_password` VARCHAR(100))   BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Em caso de erro, desfaz qualquer mudança (opcional: ROLLBACK)
        SELECT 'Erro ao criar utilizador.' AS MensagemErro;
    END;

    -- 1. Verifica se o utilizador já existe
    IF NOT EXISTS (SELECT 1 FROM utilizador WHERE Email = p_email) THEN

        -- 2. Insere na tabela
        INSERT INTO utilizador (Email, Nome, Telemovel, Tipo, Grupo)
        VALUES (p_email, p_nome, p_telemovel, p_tipo, p_grupo);

        -- 3. Cria o utilizador MySQL
        SET @sql_create = CONCAT(
            'CREATE USER ''', p_email, '''@''localhost'' IDENTIFIED BY ''', p_password, ''';'
        );
        PREPARE stmt1 FROM @sql_create;
        EXECUTE stmt1;
        DEALLOCATE PREPARE stmt1;

        -- 4. Concede a role (pré-criada) ao utilizador
	SET @sql_grant = CONCAT('GRANT ', p_tipo, ' TO ''', p_email, '''@''localhost'';');
        PREPARE stmt2 FROM @sql_grant;
        EXECUTE stmt2;
        DEALLOCATE PREPARE stmt2;

	-- 4.1 Define como role padrão
	SET @sql_default = CONCAT('SET DEFAULT ROLE ', p_tipo, ' TO ''', p_email, '''@''localhost'';');
	PREPARE stmt3 FROM @sql_default;
	EXECUTE stmt3;
	DEALLOCATE PREPARE stmt3;

        -- 5. Mensagem de sucesso
        SELECT 'Utilizador criado com sucesso!' AS Mensagem;

    ELSE
        SELECT 'Utilizador já existe.' AS Mensagem;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getIdJogo_IdUtilizador` ()   BEGIN
	DECLARE v_id_utilizador INT;
    DECLARE v_email VARCHAR(50);

    -- Extrai o email do utilizador atual (até o '@')
    SET v_email = SUBSTRING_INDEX(USER(), '@', 2);

    -- Tenta obter o ID do utilizador
    SELECT IDUtilizador INTO v_id_utilizador
    FROM utilizador
    WHERE Email = v_email;

    -- Retorna o ID do jogo mais recente criado por esse utilizador
    SELECT IDJogo, v_id_utilizador AS IDUtilizador
    FROM jogo
    WHERE IDUtilizador = v_id_utilizador
    ORDER BY IDJogo DESC
    LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_jogos` ()   BEGIN
    DECLARE email_atual VARCHAR(100);

    -- Extrai apenas o nome de utilizador da função USER() (antes do @)
    SET email_atual = SUBSTRING_INDEX(USER(), '@', 2);

    -- Retorna os jogos do utilizador autenticado
    SELECT j.IDJogo, j.NickJogador
    FROM jogo j
    JOIN utilizador u ON j.IDUtilizador = u.IDUtilizador
    WHERE u.Email = email_atual
    	AND j.Estado = 'nao_inicializado';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_marsami_room` ()   BEGIN
	SELECT * 
    FROM sala 
    WHERE IDJogo_Sala = (SELECT MAX(IDJogo_Sala) FROM sala)
    ORDER BY IDSala;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_mensagens` ()   BEGIN
    SELECT Msg, Leitura, TipoAlerta, Hora, HoraEscrita
    FROM mensagens
    WHERE Hora >= NOW() - INTERVAL 60 MINUTE
    ORDER BY Hora DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_sensores` (IN `p_idjogo` INT(50))   BEGIN
	SELECT s.Hour, s.Sound,j.normal_noise
    FROM sound s
    JOIN jogo j ON j.IDJogo = p_idJogo
    WHERE s.IDJogo = p_idJogo AND s.Hour >= NOW() - INTERVAL 10 SECOND
    ORDER BY s.Hour DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `iniciar_jogo` (IN `p_idjogo` INT)   BEGIN
    DECLARE v_id_utilizador INT;
    DECLARE v_email VARCHAR(50);
    DECLARE timenow timestamp;

    set timenow = CURRENT_TIMESTAMP;

    SET v_email = SUBSTRING_INDEX(USER(), '@', 2);

    SELECT IDUtilizador INTO v_id_utilizador
    FROM utilizador
    WHERE Email = v_email;

    IF EXISTS (
        SELECT * FROM jogo
        WHERE IDJogo = p_idjogo
        AND Estado = 'nao_inicializado'
        AND IDUtilizador = v_id_utilizador
    ) THEN
        UPDATE jogo
        SET Estado = 'jogando', DataHoraInicio = timenow
        WHERE IDJogo = p_idjogo;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Você não tem permissão para alterar este jogo.';
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `remover_utilizador` (IN `p_email` VARCHAR(50))   BEGIN
    DECLARE v_IDUtilizador INT(100);

    -- 1. Verifica se o utilizador existe e obtém o email
    SELECT IDUtilizador INTO v_IDUtilizador
    FROM utilizador
    WHERE Email = p_email;

    -- 2. Se encontrou o email, continua
    IF p_email IS NOT NULL THEN
        -- 3. Remove da tabela pisid.utilizador
        DELETE FROM utilizador WHERE IDUtilizador = v_IDUtilizador;

        -- 4. Remove o utilizador do MySQL
        SET @sql_drop = CONCAT(
            'DROP USER IF EXISTS ''', p_email, '''@''localhost'''
        );
        PREPARE stmt1 FROM @sql_drop;
        EXECUTE stmt1;
        DEALLOCATE PREPARE stmt1;
    END IF;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `jogo`
--

CREATE TABLE `jogo` (
  `IDJogo` int(11) NOT NULL,
  `NickJogador` varchar(50) DEFAULT NULL,
  `DataHoraInicio` timestamp NULL DEFAULT NULL,
  `DataHoraFim` timestamp NULL DEFAULT NULL,
  `Estado` enum('nao_inicializado','jogando','finalizado') DEFAULT NULL,
  `max_sound` float DEFAULT NULL,
  `IDUtilizador` int(11) NOT NULL,
  `normal_noise` float DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `jogo`
--

INSERT INTO `jogo` (`IDJogo`, `NickJogador`, `DataHoraInicio`, `DataHoraFim`, `Estado`, `max_sound`, `IDUtilizador`, `normal_noise`) VALUES
(1, 'Mufasa alt', '2025-05-10 02:01:29', NULL, 'jogando', NULL, 6, NULL),
(2, 'Hulk', NULL, NULL, 'nao_inicializado', NULL, 6, NULL);

--
-- Triggers `jogo`
--
DELIMITER $$
CREATE TRIGGER `criar_salas_apos_criar_jogo` AFTER INSERT ON `jogo` FOR EACH ROW BEGIN
  DECLARE i INT DEFAULT 0;

  -- Criação das 11 salas (de 0 a 10) para o novo jogo
  WHILE i <= 10 DO
    -- Verifica se a combinação de IDJogo_Sala e IDSala já existe na tabela
    IF NOT EXISTS (SELECT 1 FROM sala WHERE IDJogo_Sala = NEW.IDJogo AND IDSala = i) THEN
      -- Se for a sala 0, coloca valores específicos para MarsamiOdd e MarsamiEven
      IF i = 0 THEN
        INSERT INTO sala (IDJogo_Sala, IDSala, NumeroMarsamisOdd, NumeroMarsamisEven, Pontos, Gatilhos)
        VALUES (NEW.IDJogo, i, 15, 15, 0, 0);
      ELSE
        INSERT INTO sala (IDJogo_Sala, IDSala, NumeroMarsamisOdd, NumeroMarsamisEven, Pontos, Gatilhos)
        VALUES (NEW.IDJogo, i, 0, 0, 0, 0);
      END IF;
    END IF;
    SET i = i + 1;
  END WHILE;

END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `mensagens`
--

CREATE TABLE `mensagens` (
  `IDMensagem` int(11) NOT NULL,
  `Hora` timestamp NULL DEFAULT NULL,
  `Leitura` decimal(10,2) DEFAULT NULL,
  `TipoAlerta` varchar(50) DEFAULT NULL,
  `Msg` varchar(100) DEFAULT NULL,
  `IDJogo` int(11) NOT NULL,
  `HoraEscrita` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `movement`
--

CREATE TABLE `movement` (
  `IDMovement` int(11) NOT NULL,
  `Marsami` varchar(50) DEFAULT NULL,
  `RoomOrigin` varchar(50) DEFAULT NULL,
  `RoomDestiny` varchar(50) DEFAULT NULL,
  `Status` varchar(50) DEFAULT NULL,
  `IDJogo` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Triggers `movement`
--
DELIMITER $$
CREATE TRIGGER `atualizar_ocupacao_movimento` AFTER INSERT ON `movement` FOR EACH ROW BEGIN
    DECLARE marsami_num INT;
    SET marsami_num = CAST(NEW.Marsami AS UNSIGNED);

    -- Atualiza sala de origem
    IF (marsami_num % 2 = 0) THEN
        UPDATE sala 
        SET NumeroMarsamisEven = IFNULL(NumeroMarsamisEven, 0) - 1 
        WHERE IDSala = NEW.RoomOrigin;
    ELSE
        UPDATE sala 
        SET NumeroMarsamisOdd = IFNULL(NumeroMarsamisOdd, 0) - 1 
        WHERE IDSala = NEW.RoomOrigin;
    END IF;

    -- Atualiza sala de destino
    IF (marsami_num % 2 = 0) THEN
        UPDATE sala 
        SET NumeroMarsamisEven = IFNULL(NumeroMarsamisEven, 0) + 1 
        WHERE IDSala = NEW.RoomDestiny;
    ELSE
        UPDATE sala 
        SET NumeroMarsamisOdd = IFNULL(NumeroMarsamisOdd, 0) + 1 
        WHERE IDSala = NEW.RoomDestiny;
    END IF;

    -- Verifica a sala de origem
    IF EXISTS (
        SELECT 1 FROM sala 
        WHERE IDSala = NEW.RoomOrigin
          AND IFNULL(NumeroMarsamisEven,0) = IFNULL(NumeroMarsamisOdd,0)
    ) THEN
        INSERT INTO mensagens (IDJogo, Hora,Leitura, TipoAlerta, Msg, HoraEscrita)
        VALUES (NEW.IDJogo, null, 0, 'Alerta Igualdade', 
                CONCAT('Sala de origem ', NEW.RoomOrigin, ': Número de Marsamis Even e Odd iguais.'), 
                NOW());
    END IF;

    -- Verifica a sala de destino
    IF EXISTS (
        SELECT 1 FROM sala 
        WHERE IDSala = NEW.RoomDestiny 
          AND IFNULL(NumeroMarsamisEven,0) = IFNULL(NumeroMarsamisOdd,0)
    ) THEN
        INSERT INTO mensagens (IDJogo, Hora, Leitura, TipoAlerta, Msg, HoraEscrita)
        VALUES (NEW.IDJogo, null, 0, 'Alerta Igualdade', 
                CONCAT('Sala de destino ', NEW.RoomDestiny, ': Número de Marsamis Even e Odd iguais.'), 
                NOW());
    END IF;

END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `sala`
--

CREATE TABLE `sala` (
  `IDJogo_Sala` int(11) NOT NULL,
  `IDSala` int(11) NOT NULL,
  `NumeroMarsamisOdd` int(11) DEFAULT NULL,
  `NumeroMarsamisEven` int(11) DEFAULT NULL,
  `Pontos` int(11) DEFAULT NULL,
  `Gatilhos` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `sala`
--

INSERT INTO `sala` (`IDJogo_Sala`, `IDSala`, `NumeroMarsamisOdd`, `NumeroMarsamisEven`, `Pontos`, `Gatilhos`) VALUES
(1, 0, 15, 15, 0, 0),
(2, 0, 15, 15, 0, 0),
(1, 1, 0, 0, 0, 0),
(2, 1, 0, 0, 0, 0),
(1, 2, 0, 0, 0, 0),
(2, 2, 0, 0, 0, 0),
(1, 3, 0, 0, 0, 0),
(2, 3, 0, 0, 0, 0),
(1, 4, 0, 0, 0, 0),
(2, 4, 0, 0, 0, 0),
(1, 5, 0, 0, 0, 0),
(2, 5, 0, 0, 0, 0),
(1, 6, 0, 0, 0, 0),
(2, 6, 0, 0, 0, 0),
(1, 7, 0, 0, 0, 0),
(2, 7, 0, 0, 0, 0),
(1, 8, 0, 0, 0, 0),
(2, 8, 0, 0, 0, 0),
(1, 9, 0, 0, 0, 0),
(2, 9, 0, 0, 0, 0),
(1, 10, 0, 0, 0, 0),
(2, 10, 0, 0, 0, 0);

-- --------------------------------------------------------

--
-- Table structure for table `sound`
--

CREATE TABLE `sound` (
  `IDSound` int(11) NOT NULL,
  `Hour` datetime DEFAULT NULL,
  `Sound` float DEFAULT NULL,
  `IDJogo` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `utilizador`
--

CREATE TABLE `utilizador` (
  `Telemovel` varchar(12) DEFAULT NULL,
  `Tipo` enum('admin','jogador','software') NOT NULL,
  `Grupo` int(11) DEFAULT NULL,
  `Nome` varchar(100) DEFAULT NULL,
  `IDUtilizador` int(11) NOT NULL,
  `Email` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `utilizador`
--

INSERT INTO `utilizador` (`Telemovel`, `Tipo`, `Grupo`, `Nome`, `IDUtilizador`, `Email`) VALUES
('111222333', 'jogador', 9, 'jogador', 6, 'jogador@gmail.com'),
('444555666', 'admin', 9, 'admin', 7, 'admin@gmail.com'),
('777888999', 'software', 9, 'software', 8, 'software@gmail.com');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `jogo`
--
ALTER TABLE `jogo`
  ADD PRIMARY KEY (`IDJogo`),
  ADD KEY `IDUtilizador_Jogo` (`IDUtilizador`) USING BTREE;

--
-- Indexes for table `mensagens`
--
ALTER TABLE `mensagens`
  ADD PRIMARY KEY (`IDMensagem`) USING BTREE,
  ADD KEY `IDJogo_Mensagens` (`IDJogo`) USING BTREE;

--
-- Indexes for table `movement`
--
ALTER TABLE `movement`
  ADD PRIMARY KEY (`IDMovement`),
  ADD KEY `IDJogo_Movement` (`IDJogo`) USING BTREE;

--
-- Indexes for table `sala`
--
ALTER TABLE `sala`
  ADD PRIMARY KEY (`IDSala`,`IDJogo_Sala`) USING BTREE,
  ADD KEY `IDJogo_Sala` (`IDJogo_Sala`) USING BTREE;

--
-- Indexes for table `sound`
--
ALTER TABLE `sound`
  ADD PRIMARY KEY (`IDSound`),
  ADD KEY `IDJogo_Sound` (`IDJogo`) USING BTREE;

--
-- Indexes for table `utilizador`
--
ALTER TABLE `utilizador`
  ADD PRIMARY KEY (`IDUtilizador`),
  ADD UNIQUE KEY `Email` (`Email`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `jogo`
--
ALTER TABLE `jogo`
  MODIFY `IDJogo` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `mensagens`
--
ALTER TABLE `mensagens`
  MODIFY `IDMensagem` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `movement`
--
ALTER TABLE `movement`
  MODIFY `IDMovement` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `sound`
--
ALTER TABLE `sound`
  MODIFY `IDSound` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `utilizador`
--
ALTER TABLE `utilizador`
  MODIFY `IDUtilizador` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `jogo`
--
ALTER TABLE `jogo`
  ADD CONSTRAINT `IDUtilizador_Jogo` FOREIGN KEY (`IDUtilizador`) REFERENCES `utilizador` (`IDUtilizador`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `mensagens`
--
ALTER TABLE `mensagens`
  ADD CONSTRAINT `IDJogo_Mensagens` FOREIGN KEY (`IDJogo`) REFERENCES `jogo` (`IDJogo`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `movement`
--
ALTER TABLE `movement`
  ADD CONSTRAINT `IDJogo_Movement` FOREIGN KEY (`IDJogo`) REFERENCES `jogo` (`IDJogo`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `sala`
--
ALTER TABLE `sala`
  ADD CONSTRAINT `IDJogo_Sala` FOREIGN KEY (`IDJogo_Sala`) REFERENCES `jogo` (`IDJogo`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `sound`
--
ALTER TABLE `sound`
  ADD CONSTRAINT `IDJogo_Sound` FOREIGN KEY (`IDJogo`) REFERENCES `jogo` (`IDJogo`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
