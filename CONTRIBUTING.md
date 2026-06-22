# 🤝 Guia de Contribuição - agy-pipeline

Obrigado por seu interesse em contribuir com o **agy-pipeline**! Este projeto é **100% colaborativo** e sua ajuda é bem-vinda.

---

## 📋 Como Começar

### 1. **Fork & Clone**
```bash
# Faça um fork no GitHub
# Depois clone sua cópia:
git clone https://github.com/SEU_USUARIO/agy-pipeline.git
cd agy-pipeline
```

### 2. **Crie uma Branch**
```bash
# Crie uma branch descritiva
git checkout -b feature/sua-feature
# ou
git checkout -b fix/seu-bugfix
```

### 3. **Faça Suas Mudanças**

**Se for editar scripts Bash:**
- Mantenha o modo estrito (`set -euo pipefail`)
- Use nomes descritivos para variáveis
- Adicione comentários para lógica complexa
- Teste no sandbox antes de submeter:
  ```bash
  ./scripts/test_sandbox.sh
  ```

**Se for adicionar documentação:**
- Use Markdown limpo
- Inclua exemplos de código quando relevante
- Atualize o README se necessário

---

## 🧪 Testes Obrigatórios

Antes de submeter um PR, execute:

```bash
# Validação de scripts Bash (ShellCheck)
./scripts/test_sandbox.sh

# Se estiver usando GitHub Actions localmente:
# act -j lint
```

---

## 📝 Mensagens de Commit

Use um padrão claro:

```
feat: adiciona suporte a novo componente X
fix: corrige erro de permissão do sandbox
docs: atualiza instruções de instalação
test: adiciona testes para feature X
chore: atualiza dependências
```

---

## 🎯 Tipos de Contribuições Bem-Vindas

### 🐛 **Bug Reports**
- Descreva o comportamento esperado vs real
- Inclua seu ambiente (Ubuntu/Debian, versão)
- Forneça logs de execução

### ✨ **Novas Features**
- Abra uma **Issue** primeiro para discussão
- Explique o use case
- Aguarde feedback antes de implementar

### 📚 **Documentação**
- Melhorias no README
- Adição de exemplos práticos
- Diagramas ou tutoriais
- **Sempre bem-vindo!**

### 🔧 **Otimizações**
- Performance improvements
- Simplificações de lógica
- Melhor tratamento de erros

---

## 🔄 Fluxo de Pull Request

1. **Abra o PR** com um título descritivo
2. **Descreva as mudanças** (o quê e por quê)
3. **Referencie issues relacionadas** (`Closes #123`)
4. **Aguarde review** (pode levar alguns dias)
5. **Faça ajustes** se solicitado
6. **Merge automático** após aprovação ✅

### Exemplo de PR Description:
```markdown
## 📝 Descrição
Adiciona suporte para atualização automática de permissões do SDK.

## 🎯 Tipo de Mudança
- [x] Bug fix
- [ ] Nova feature
- [ ] Breaking change
- [x] Melhoria de documentação

## ✅ Checklist
- [x] Testei a mudança localmente
- [x] Executei o sandbox test
- [x] Atualizei a documentação
- [x] Adicionei exemplos se necessário

## 📸 Screenshots (se aplicável)
_se for visual, inclua aqui_
```

---

## 📖 Estrutura do Projeto

```
agy-pipeline/
├── scripts/
│   ├── atualizar_antigravity.sh   # Script principal
│   └── test_sandbox.sh             # Testes isolados
├── .github/
│   └── workflows/
│       └── lint.yml                # CI/CD validação
├── Docs/
│   ├── analise_viabilidade_pipeline.md
│   ├── analise_viabilidade_testes.md
│   └── parecer_tecnico_unificacao.md
├── README.md
├── CONTRIBUTING.md                 # ← Você está aqui
├── LICENSE                         # MIT License
└── .env.exemplo
```

---

## 🚀 Roteiro de Desenvolvimento (Roadmap)

Veja as **Issues** para o roadmap completo. Áreas prioritárias:

- [ ] Integração com GitHub Actions para CI/CD automático
- [ ] Suporte a macOS (além de Linux)
- [ ] Notificações de atualização (Webhook/Discord)
- [ ] Dashboard de status
- [ ] Testes em distros adicionais

**Interesse em alguma?** Deixe um comentário na Issue correspondente!

---

## 💬 Perguntas & Suporte

- **Dúvidas sobre contribuição?** Abra uma [Discussion](https://github.com/RafaeldsSiqueira/agy-pipeline/discussions)
- **Problema específico?** [Abra uma Issue](https://github.com/RafaeldsSiqueira/agy-pipeline/issues)
- **Quer conversar?** Menção [@RafaeldsSiqueira](https://github.com/RafaeldsSiqueira)

---

## 📜 Código de Conduta

Somos uma comunidade acolhedora. Esperamos que todos:

✅ Sejam respeitosos  
✅ Aceitem críticas construtivas  
✅ Focalizem o que é melhor para a comunidade  
❌ Sem assédio, discriminação ou comportamento tóxico

---

## 🎉 Obrigado!

Sua contribuição, por menor que seja, faz diferença. Você será mencionado em futuras releases como contribuidor! 🌟

---

**Happy Coding! 🚀**
