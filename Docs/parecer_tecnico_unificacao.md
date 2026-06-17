# Parecer Técnico: Unificação da Pipeline com Fontes Oficiais

Este parecer avalia a praticidade, validade de funcionamento e a necessidade dos processos propostos para a unificação do script de atualização com as fontes de distribuição oficiais do ecossistema **Antigravity 2.0**.

---

## 1. Análise por Componente

### 📦 A. Antigravity SDK (Python)
*   **Abordagem Anterior**: Baixar um `.tar.gz` do GitHub e extrair em uma pasta local (`~/antigravity-sdk`).
*   **Abordagem Oficial**: Executar `pip install --upgrade google-antigravity`.
*   **Parecer (ALTAMENTE RECOMENDADO)**: A abordagem anterior é **impraticável** para desenvolvimento no dia a dia. Bibliotecas Python precisam ser instaladas no ambiente Python (`site-packages` do sistema ou de um ambiente virtual `venv`) para que os scripts consigam importá-las diretamente com `import google_antigravity`. A migração para o `pip` é tecnicamente correta, mais simples e elimina etapas complexas de extração de pastas.

### 💻 B. Antigravity CLI (agy)
*   **Abordagem Anterior**: Baixar `.tar.gz` do GitHub e extrair em `~/antigravity-cli`.
*   **Abordagem Oficial**: Executar o instalador do Google via `curl -fsSL https://antigravity.google/cli/install.sh | bash`.
*   **Parecer (RECOMENDADO)**: O instalador oficial é mais prático porque ele já adiciona o binário `agy` automaticamente ao `PATH` do sistema e configura dependências internas. No entanto, é prudente manter um *fallback* (retorno seguro) no script para buscar do GitHub Releases caso os servidores da Google (`antigravity.google`) fiquem indisponíveis.

### 🖥️ C. Antigravity 2.0 / IDE (Desktop)
*   **Abordagem Anterior**: Baixar `.tar.gz`, extrair de forma limpa e corrigir permissões do `chrome-sandbox`.
*   **Abordagem Oficial**: O aplicativo se auto-atualiza em segundo plano, e downloads novos vêm de `https://antigravity.google/download`.
*   **Parecer (ÚTIL E VÁLIDO)**: Embora o app se auto-atualize, desenvolvedores frequentemente precisam rodar builds portáveis ou reinstalar a aplicação do zero. Além disso, **a correção das permissões do SUID Sandbox (`chrome-sandbox`) é o principal valor do nosso script**, pois a auto-atualização do Electron no Linux frequentemente falha em aplicar o bit SUID, exigindo intervenção manual com `sudo`. Portanto, manter esse fluxo no script é **totalmente necessário**.

---

## 2. Resumo da Viabilidade e Praticidade

A unificação sob o script centralizado é **extremamente prática e válida**. Em vez de rodar 3 ferramentas diferentes, o desenvolvedor gerencia todo o ecossistema com um único comando central.

| Componente | Ação Proposta no Script Unificado | Validade Técnica |
| :--- | :--- | :--- |
| `sdk` | Executa `pip install --upgrade google-antigravity` | **Excelente** (Padrão de mercado) |
| `cli` | Executa o instalador oficial via `curl` com fallback no GitHub | **Alta** (Garante o `PATH` correto) |
| `ide` / `2.0` | Mantém download do `.tar.gz` com correção de permissões do Sandbox | **Alta** (Resolve o problema do SUID) |

---

