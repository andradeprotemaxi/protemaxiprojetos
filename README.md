# Protemaxi Projetos

App de projetos de **CFTV, alarme e cerca elétrica** do Grupo Protemaxi. Funciona no computador, no celular e no navegador (instalável como aplicativo).

- **Login com PIN de 4 números**, trava após 5 erros e bloqueio automático por inatividade
- Só e-mails liberados na **Equipe** veem os projetos (regra no banco, não só na tela)
- Painel com totais coloridos (total, novos, em execução, concluídos) e passo a passo das etapas
- Projeto com fotos (com legenda), planta, descrição, escopo e logo do cliente
- Editor de planta com posicionamento automático e ajuste manual
- **Catálogo no padrão Inside** (código, produto, unitário, grupo CFTV/ALARME) com cálculo automático das quantidades
- Apresentação no **modelo oficial Protemaxi** em PowerPoint editável e PDF
- **Lista Inside** (.csv) com Código; Produto; Quantidade; Unitário; Total; GrupoOrçamento

## Slides gerados (modelo Mall Jardins de Fátima)
1. Capa — "PROPOSTA FINANCEIRA - NOME DO PROJETO" + logo Protemaxi + selo (ou logo do cliente)
2. Escopo
3. Fotos do local — 6 por slide, moldura azul e legenda
4. Croqui — prancha com planta, câmeras, sensores, legenda, quantitativo e cabos
5. Equipamentos e Materiais — nomes simples, sem especificação técnica
6. Funcionamento do sistema + principais benefícios
7. Proposta financeira (opcional, por projeto)
8. Encerramento com endereço e contatos

---

## Passo a passo para colocar no ar

> Faça no Chrome em que você está logado no GitHub e no Supabase.

### 1. Supabase
1. **supabase.com → New project** · nome `protemaxi-projetos` · região **South America (São Paulo)** · crie e guarde a senha do banco.
2. Abra `supabase/schema.sql`, troque o e-mail da **última linha** pelo seu e-mail de administrador.
3. **SQL Editor → New query** → cole o arquivo inteiro → **Run** (deve aparecer *Success*).
4. **Authentication → Sign In / Providers → Email**:
   - deixe **Email** ativo;
   - desligue **Confirm email** (o acesso já é controlado pela lista da equipe);
   - mantenha o tamanho mínimo de senha no padrão (6) — o app cuida do PIN.
5. **Project Settings → API**: copie a **Project URL** e a **anon public key** (nunca a `service_role`) e cole no `config.js`:
   ```js
   window.PROTEMAXI_CONFIG = {
     supabaseUrl: "https://SEU-PROJETO.supabase.co",
     supabaseAnonKey: "eyJhbGciOi..."
   };
   ```

### 2. GitHub
1. **github.com → + → New repository** · nome `protemaxi-projetos` · **Public** · **Create repository**.
2. **Add file → Upload files** → arraste **tudo que está dentro** da pasta (inclusive as pastas `assets` e `supabase`) → **Commit changes**.
3. **Settings → Pages** → *Deploy from a branch* → **main** / **(root)** → **Save**.
4. Em 1–3 minutos sai o link: `https://SEU-USUARIO.github.io/protemaxi-projetos/`

### 3. Ligar o login ao site
Supabase → **Authentication → URL Configuration** → cole o link do GitHub Pages em **Site URL** e em **Redirect URLs** → Save.

### 4. Primeiro acesso
1. Abra o link → **Primeiro acesso** → digite o e-mail de administrador → escolha o PIN de 4 números → confirme.
2. Engrenagem → **Perfil**: complete telefone e contatos (vão no slide de encerramento).
3. Engrenagem → **Catálogo (Inside)**: confira preços; os itens "(DEFINIR MODELO)" estão com preço zero.
4. Para liberar alguém: engrenagem → **Equipe** → e-mail → **Liberar acesso**. A pessoa entra em *Primeiro acesso* e cria o PIN dela.

### 5. Instalar como aplicativo
- **Computador (Chrome/Edge):** ícone de instalar na barra de endereço.
- **Android:** menu ⋮ → *Instalar app*.
- **iPhone (Safari):** Compartilhar → *Adicionar à Tela de Início*.

### Atualizar depois
GitHub → **Add file → Upload files** → envie o arquivo novo com o mesmo nome → **Commit**.

---

## Sobre a segurança do PIN
Um PIN de 4 números tem só 10 mil combinações, então ele **não é a única proteção**:
- o app trava após 5 erros (30 s, 1 min, 2 min… dobrando), e o Supabase limita tentativas de login por IP;
- só e-mails da **Equipe** acessam dados — uma conta criada por estranho não vê nada;
- dados e fotos ficam em banco e armazenamento **privados**, com regras de acesso no servidor;
- o app bloqueia sozinho após 20 min sem uso (ajustável em Parâmetros);
- para reforçar: ative **CAPTCHA** em Authentication → Attack Protection, e mantenha a lista da equipe enxuta.

## Atualizar preços pelo Inside
Engrenagem → **Catálogo (Inside)** → copie as linhas do orçamento no Inside, cole na caixa **Atualizar preços pelo Inside** → **Atualizar catálogo** → **Salvar**. Códigos existentes têm o preço atualizado; códigos novos entram desativados para você configurar.

**DWG/DXF:** no AutoCAD use Plotar (Ctrl+P) → *DWG To PDF.pc3* e envie o PDF.
