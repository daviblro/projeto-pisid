import React, { useEffect, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import axios from 'axios';
import './HomePage.css'; // reutilizando o estilo

function AlterarJogo() {
    const location = useLocation();
    const navigate = useNavigate();
    const { idJogo } = location.state || {};

    const [user] = useState(() => {
        const storedUser = localStorage.getItem('user');
        return storedUser ? JSON.parse(storedUser) : null;
    });

    const [nickJogador, setNickJogador] = useState("");
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!idJogo || !user) {
            navigate('/home');
            return;
        }

        // Buscar dados atuais do jogo
        axios.get(`http://localhost/getJogo.php?idJogo=${idJogo}`)
            .then(res => {
                setNickJogador(res.data.NickJogador);
                setLoading(false);
            })
            .catch(() => navigate('/home'));
    }, [idJogo, user, navigate]);

    const handleUpdate = () => {
        axios.post('http://localhost/alterarJogo.php', {
            idJogo,
            nickJogador,
            idUtilizador: user.id
        }).then(() => {
            alert("Jogo alterado com sucesso!");
            navigate('/home');
        }).catch(err => {
            console.error("Erro ao alterar jogo", err);
            alert("Erro ao alterar jogo.");
        });
    };

    if (loading) return <p>Carregando...</p>;

    return (
        <div className="home-container">
            <header className="home-header">
                <h2>Bem-vindo, {user?.nome} ({user?.email})</h2>
            </header>
            
            <div className="home-content">
                <label>Novo Nick do Jogador:</label>
                <input
                    type="text"
                    value={nickJogador}
                    onChange={(e) => setNickJogador(e.target.value)}
                />
                <button onClick={handleUpdate}>Alterar</button>
                <button onClick={() => navigate('/home')}>Voltar atrás</button>
            </div>
        </div>
    );
}

export default AlterarJogo;
