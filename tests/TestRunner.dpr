program TestRunner;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}{$H+}
{$ENDIF}

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Horse.RBAC.Tests in 'Horse.RBAC.Tests.pas',
  Horse.RBAC in '../src/Horse.RBAC.pas';

var
  LSuccess: Boolean;
begin
  try
    LSuccess := THorseRBACTests.RunAllTests;
    if LSuccess then
    begin
      WriteLn('----------------------------------------');
      WriteLn('TODOS OS TESTES PASSARAM COM SUCESSO!');
      WriteLn('----------------------------------------');
      ExitCode := 0;
    end
    else
    begin
      WriteLn('----------------------------------------');
      WriteLn('ERRO: ALGUNS TESTES FALHARAM!');
      WriteLn('----------------------------------------');
      ExitCode := 1;
    end;
  except
    on E: Exception do
    begin
      WriteLn('Excecao fatal durante a execucao dos testes: ' + E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
  
  // Se rodar de forma interativa no terminal, aguarda uma tecla
  if IsConsole and not (GetEnvironmentVariable('CI') = 'true') then
  begin
    Write('Pressione ENTER para fechar...');
    ReadLn;
  end;
end.
