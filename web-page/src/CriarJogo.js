import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import './HomePage.css';

function CriarJogo() {
    const navigate = useNavigate();
    const [user] = useState(() => {
        const storedUser = localStorage.getItem('user');
        return storedUser ? JSON.parse(storedUser) : null;
    });
    const [nickJogador, setNickJogador] = useState("");


    useEffect(() => {
        if (!user) {
            navigate('/');
            return;
        }
    }, [user, navigate]);

    const handleCriar = () => {
        if (!nickJogador.trim()) {
            alert("O nick do jogador é obrigatório.");
            return;
        }

        axios.post('http://localhost/criarJogo.php', {
            nickJogador,
            email: user.email
        }).then(res => {
            alert(res.data.message || "Jogo criado com sucesso!");
            navigate('/home');
        }).catch(err => {
            console.error("Erro ao criar jogo", err);
            alert("Erro ao criar jogo.");
        });
    };

    return (
        <div className="home-container">
            <header className="home-header">
                <h2>Bem-vindo, {user?.nome} ({user?.email})</h2>
            </header>
            
            <div className="home-content">
                <label>Nick do Jogador:</label>
                <input
                    type="text"
                    value={nickJogador}
                    onChange={(e) => setNickJogador(e.target.value)}
                />
                <button onClick={handleCriar}>Criar</button>
                <button onClick={() => navigate('/home')}>Voltar atrás</button>
            </div>
        </div>
    );
}

export default CriarJogo;
