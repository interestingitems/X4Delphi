program Project1;





{$R *.dres}

uses
  System.StartUpCopy,
  FMX.Forms,
  unit2 in 'unit2.pas' {Form2};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
