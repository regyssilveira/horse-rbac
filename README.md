<p align="center">
  <a href="https://github.com/HashLoad/horse/blob/master/img/horse.png">
    <img alt="Horse" height="150" src="https://github.com/HashLoad/horse/blob/master/img/horse.png">
  </a>
</p><br>
<p align="center">
  <b>horse-rbac</b> é um middleware de controle de acesso baseado em funções (RBAC) e escopos para o framework <a href="https://github.com/HashLoad/horse">Horse</a>.
</p><br>

## ⚙️ Instalação

A instalação é feita utilizando o comando [`boss install`](https://github.com/HashLoad/boss):

```sh
boss install github.com/user/horse-rbac
```

---

## ⚡️ Quickstart

Para utilizar o `horse-rbac`, basta declarar a unit `Horse.RBAC` e injetar o middleware nas rotas desejadas. O middleware lê o payload do token JWT diretamente de `Req.Session` (injetado previamente por qualquer middleware de autenticação, como o `horse-jwt`).

```delphi
uses
  Horse,
  Horse.JWT,
  Horse.RBAC;

begin
  // Middleware global de autenticação JWT
  THorse.Use(HorseJWT('sua_chave_secreta_jwt'));

  // Rota protegida: Exige a permissão 'pedidos:read' (Lógica OR por padrão)
  THorse.Get('/pedidos', [RBAC(['pedidos:read'])],
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      Res.Send('Acesso concedido aos pedidos!');
    end);

  THorse.Listen(9000);
end.
```

---

## 🛠️ Configuração e Assinatura

O middleware é inicializado através da função `RBAC`:

```delphi
function RBAC(const APermissions: array of string; const AClaimName: string = 'permissions'; const AVerifyAll: Boolean = False): THorseCallback;
```

### Parâmetros:
* **`APermissions`**: Array de strings contendo os escopos/permissões granulares necessários para acessar a rota (ex: `['pedidos:read']`, `['pedidos:write', 'entidades:write']`).
* **`AClaimName`**: Nome da chave (claim) dentro do objeto JSON da sessão onde estão listadas as permissões do usuário. O padrão é `'permissions'`.
* **`AVerifyAll`**: Lógica de checagem quando há múltiplos escopos requeridos:
  - `False` (Padrão - **Lógica OR**): O usuário precisa possuir *pelo menos uma* das permissões informadas no array para ter acesso concedido.
  - `True` (**Lógica AND**): O usuário precisa possuir *todas* as permissões listadas no array para ter acesso concedido.

---

## 📦 Formato Esperado da Claim no JWT

O middleware processa exclusivamente a claim do JWT contendo as permissões no formato de **JSON Array de Strings**:

```json
{
  "sub": "1234567890",
  "name": "João Silva",
  "permissions": [
    "pedidos:read",
    "pedidos:write",
    "entidades:write"
  ]
}
```

---

## 🛑 Tratamento de Erros e Interrupção (Padrão Horse)

Em conformidade com o ecossistema do Horse:
* Caso a sessão JWT não seja encontrada em `Req.Session` (usuário não autenticado), o middleware retorna status **`401 Unauthorized`** e interrompe o pipeline levantando a exceção `EHorseCallbackInterrupted`.
* Caso as permissões do usuário sejam insuficientes ou a claim especificada não seja um JSON Array válido, o middleware retorna status **`403 Forbidden`** e interrompe a requisição imediatamente de forma limpa.

---

## 📄 Integração com o GBSwagger

O `horse-rbac` integra-se perfeitamente com a documentação automática de segurança do **GBSwagger**.

### Configuração do Esquema no Swagger:
```delphi
  GBSwagger
    .Register
      .Security
        .Bearer('Bearer')
          .Description('Autenticação baseada em token JWT.');
```

### Anotação nos Controllers:
```delphi
type
  [SwagPath('pedidos', 'Pedidos')]
  TPedidosController = class
  public
    [SwagGET('Listar pedidos')]
    [SwagSecurity('Bearer', ['pedidos:read'])] // <-- Associa o escopo do Swagger
    procedure Get(Req: THorseRequest; Res: THorseResponse);
  end;
```

---

## 💻 Compatibilidade

* **Delphi XE7** e superiores (compatível com sintaxe clássica e sem variáveis inline).
* **Lazarus / Free Pascal (FPC)** (compatibilidade garantida via diretivas de compilação utilizando `fpjson`).
* Desenvolvido sob princípios **Clean Code**, **SOLID** e thread-safe.

---

## 📄 Licença

Este projeto está licenciado sob a [Licença MIT](LICENSE).
