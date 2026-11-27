# revezamento-agy

Roda o [Antigravity CLI](https://antigravity.google) (`agy`) em várias contas Google **ao mesmo tempo** no Mac e reveza entre elas sozinho. Quando uma conta fica sem cota, o pedido passa para a próxima com um aviso para continuar de onde parou.

Serve para quem usa o `agy` como "mão de obra" de outro agente (Claude Code, Codex, um script) e quer espalhar o consumo pelas cotas de várias contas em vez de esgotar uma só.

```text
você / Claude Code
        │  agy-rodar -p "pedido"
        ▼
   agy-rodar.sh ──► escolhe a próxima conta, confere se ela tem o modelo
        │
        ▼
   agy-conta.sh ──► roda o agy com o HOME daquela conta, num sandbox
        │
        ├─ terminou ─────────────► devolve a saída
        └─ "Individual quota reached" ─► tenta a próxima conta
```

Dois scripts em Bash, sem dependência além do próprio `agy`.

| Arquivo | O que faz |
|---|---|
| `agy-conta.sh` | Roda o agy numa conta específica. Várias contas rodam em paralelo sem se atropelar. |
| `agy-rodar.sh` | Escolhe a conta, pula a que não tem o modelo e a que está sem cota. |
| `teste-agy-rodar.sh` | Testa o revezamento com um agy falso (não gasta cota). |

## Por que não basta trocar o HOME

O agy guarda o login no **Keychain do macOS**, num item único por usuário. Rodar `HOME=/outra/pasta agy` continua usando a mesma conta, e duas execuções em paralelo brigam pelo mesmo token.

Quando não consegue falar com o Keychain, o agy cai para um arquivo dentro do HOME (`~/.gemini/antigravity-cli/antigravity-oauth-token`). O `agy-conta.sh` usa isso a seu favor: roda o agy dentro do `sandbox-exec` com o `/usr/bin/security` proibido. Assim cada conta lê e renova o token só no arquivo do próprio HOME, e as contas ficam isoladas de verdade.

## Requisitos

- macOS (o isolamento depende do `sandbox-exec`, que vem no sistema).
- Antigravity CLI instalado.
- Uma ou mais contas Google com acesso ao Antigravity.

No Linux e no Windows o `agy-rodar.sh` ainda funciona, mas roda o agy direto numa conta só.

## Instalação passo a passo

### 1. Instale o agy

```bash
curl -fsSL https://antigravity.google/cli/install.sh | bash
```

Ele vai para `~/.local/bin/agy`. Confira:

```bash
agy --version
```

Se der "command not found", ponha `~/.local/bin` no PATH:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

### 2. Baixe os scripts

```bash
git clone https://github.com/gabrielkashimarki/revezamento-agy.git ~/revezamento-agy
```

### 3. Deixe os comandos no PATH

```bash
ln -s ~/revezamento-agy/agy-conta.sh ~/.local/bin/agy-conta
```

```bash
ln -s ~/revezamento-agy/agy-rodar.sh ~/.local/bin/agy-rodar
```

### 4. Logue a conta principal

A conta `principal` é a que usa o seu HOME normal.

```bash
agy-conta principal --logar
```

Faça isso mesmo se você já usa o agy: o login antigo fica no Keychain, e aqui ele precisa ser gravado no arquivo do HOME. Abre o agy interativo. Faça o login pelo navegador e saia (`/quit` ou Ctrl+C).

### 5. Logue as outras contas

Cada conta extra ganha um nome curto e uma pasta `~/agy-<nome>`, que vira o HOME dela. Use letras, números, ponto, hífen ou sublinhado.

```bash
agy-conta trabalho --logar
```

```bash
agy-conta pessoal --logar
```

Em cada uma, faça login com uma conta Google **diferente**. A pasta é criada sozinha.

### 6. Confira se cada conta é quem deveria ser

```bash
agy-conta trabalho models
```

Tem que listar os modelos. Para ver com qual e-mail ela autenticou:

```bash
grep 'authenticated successfully as' ~/agy-trabalho/.gemini/antigravity-cli/cli.log | tail -1
```

### 7. Rode o teste

```bash
bash ~/revezamento-agy/teste-agy-rodar.sh
```

Tem que imprimir `OK`. O teste usa uma conta falsa e não gasta cota.

## Uso

### Deixar o revezamento escolher a conta

```bash
agy-rodar -p "Renomeie a função foo para bar em src/ e rode os testes" \
  --add-dir ~/meu-projeto --dangerously-skip-permissions --print-timeout 120m
```

O que acontece:

1. Cada chamada começa na conta seguinte à da chamada anterior.
2. Antes de despachar, confere em `agy models` se a conta tem o modelo pedido. Se não tiver, pula.
3. Se a saída trouxer `Individual quota reached`, tenta a próxima conta. O pedido ganha um aviso para conferir `git status` e `git diff` antes de começar, porque a conta anterior pode ter deixado trabalho pela metade.
4. Se nenhuma conta servir, sai com código `75`.

### Fixar uma conta

```bash
agy-conta trabalho -p "..." --model gemini-3.8-flash-high --add-dir ~/meu-projeto
```

### Rodar várias ao mesmo tempo

Cada conta é isolada, então dá para abrir uma por terminal, ou em segundo plano:

```bash
agy-rodar -p "tarefa A" --add-dir ~/repo-a --dangerously-skip-permissions &
agy-rodar -p "tarefa B" --add-dir ~/repo-b --dangerously-skip-permissions &
wait
```

Duas execuções no mesmo repositório se atropelam. Use um worktree git para cada uma.

## Configuração

Tudo por variável de ambiente, nada obrigatório.

| Variável | Padrão | Para quê |
|---|---|---|
| `AGY_CONTAS` | `principal` mais toda pasta `~/agy-*` | Lista e ordem das contas, separadas por espaço. Ex: `"principal trabalho"` |
| `AGY_MODELO` | `gemini-3.8-flash-high` | Modelo usado quando o pedido não traz `--model` |
| `AGY_RODAR_ESTADO` | `~/.cache/agy-rodar/proxima` | Onde fica guardada a próxima conta do revezamento |
| `AGY_CONTA_BIN` | `agy-conta` do PATH | Outro executável no lugar do `agy-conta.sh` (o teste usa isso) |

Os ids de modelo mudam com o tempo e de conta para conta. `agy-conta <nome> models` mostra os de cada uma. Com id inválido o agy só imprime a lista e sai sem fazer nada, por isso o revezamento confere antes.

Cuidado com a detecção automática: **qualquer** pasta `~/agy-<algo>` vira conta. Se tiver outra pasta com esse prefixo, defina `AGY_CONTAS`.

## Usando com o Claude Code

A ideia original: o Claude planeja, revisa e cuida da lógica difícil; o trabalho mecânico (aplicar um plano já decidido, renomear, gerar variações) vai para o agy, que consome a cota do plano Google e não a do Claude.

1. Libere o comando nas permissões do Claude Code (`~/.claude/settings.json`), senão o modo automático pode barrar a chamada:

   ```json
   { "permissions": { "allow": ["Bash(agy-rodar:*)", "Bash(agy-conta:*)"] } }
   ```

2. Peça ao Claude para despachar cada tarefa com `agy-rodar`, com objetivo, arquivos permitidos, critério de aceite e os comandos de checagem no pedido.
3. Cada tarefa num worktree git próprio.
4. O Claude lê o diff e roda os testes antes de juntar. "Terminei" do agy não é prova.

O agy não guarda estado entre chamadas. Retomar uma tarefa é despachar de novo com o pedido, o relatório anterior e o `git diff`.

## Problemas comuns

**`conta X sem login: rode 'agy-conta X --logar'`**
A pasta da conta não tem o arquivo de token. Faça o passo 5 para ela.

**Duas contas aparecem com o mesmo e-mail**
Você logou a mesma conta Google duas vezes. Apague `~/agy-<nome>/.gemini/antigravity-cli/antigravity-oauth-token` e logue de novo, escolhendo a outra conta no navegador.

**`agy-rodar: conta X sem o modelo ...`**
Essa conta não tem aquele modelo. Ela é pulada; tudo certo se outra tiver. Para usar um modelo que só uma conta tem, fixe a conta com `agy-conta`.

**Saiu com código 75**
Todas as contas estão sem cota ou sem o modelo. A cota costuma voltar em algumas horas.

**Script filho do agy precisa do Keychain (ex: 1Password CLI)**
Dentro do sandbox ninguém roda `/usr/bin/security`, nem os processos que o agy abre. Passe o segredo já pronto no ambiente antes de chamar (ex: `OP_SERVICE_ACCOUNT_TOKEN`).

**O run caiu no meio (cota, rede)**
O que foi commitado fica. O resto está no disco. Rode de novo pelo `agy-rodar`, que manda a próxima conta conferir o `git diff` e continuar.

## Desinstalar

```bash
rm ~/.local/bin/agy-conta ~/.local/bin/agy-rodar
```

As pastas `~/agy-<nome>` guardam o login de cada conta. Apague só se não for mais usar a conta.

## Licença

MIT
