unit Twitter.Client;

interface

uses
  System.SysUtils, System.Classes, Twitter.Core, Twitter.Api.Types,
  Json, REST.Json,System.Net.Mime,FMX.Dialogs ;


type

  TTwitter = class(TComponent)
  private
    FConsumerKey   : string;
    FConsumerSecret: string;
    FAccessToken   : string;
    FTokenSecret   : string;
    FBearerToken   : string;

    procedure SetConsumerKey   (const AConsumerKey :String);
    procedure SetConsumerSecret(const AConsumerSecret :String);
    procedure SetAccessToken   (const AAccessToken :String);
    procedure SetTokenSecret   (const ATokenSecret :String);
    procedure SetBearerToken   (const ABearerToken :String);

    function  LvRequest <T:class,constructor>(AMethod, AUrl: String; ABody: TStringStream; AParams : TStringList=nil):T;

  protected
    { Protected declarations }
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;

    function CreateTweet (AText: String):TTweetResponse;
    function DeleteTweet(AId: string): TTweetRespDeleted;
    function CreateTweetWithContent(AText: String; AMedia:String):string;

  published
    property ConsumerKey    : String  read FConsumerKey      write SetConsumerKey;
    property ConsumerSecret : String  read FConsumerSecret   write SetConsumerSecret;
    property AccessToken    : String  read FAccessToken      write SetAccessToken;
    property TokenSecret    : String  read FTokenSecret      write SetTokenSecret;
    property BearerToken    : String  read FBearerToken      write SetBearerToken;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Twitter', [TTwitter]);
end;

{ TTwitter }

constructor TTwitter.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
end;

function TTwitter.CreateTweet(AText: String): TTweetResponse;
const
  LUrl = 'https://api.twitter.com/2/tweets';
var
  LBody    : TStringStream;
  LJsonObj : TJSONObject;
begin
  result   := nil;
  LBody    := TStringStream.Create('');
  LJsonObj := TJSONObject.Create;
  try
    LJsonObj.AddPair('text', AText);
    LBody.WriteString(LJsonObj.ToJSON);
    LBody.Position := 0;
    ClientBase.ContentType  := 'application/json';
    result := LvRequest<TTweetResponse>('POST',LUrl,LBody);
   except
    raise Exception.Create('Error Message');
  end;
  LBody.Free;
  LJsonObj.Free;
end;

function TTwitter.CreateTweetWithContent(AText, AMedia: String): string;
const
  LUrlM = 'https://upload.twitter.com/1.1/media/upload.json';
  LUrl = 'https://api.twitter.com/2/tweets';
var
  LBody    : TStringStream;
  LJsonObj : TJSONObject;
  LParam   : TMultipartFormData;
  tmpResp  : TTwitterMediaInfo;
begin
  result := '';
  LParam := TMultipartFormData.Create;
  LParam.AddFile('media',AMedia);
  var LResponse := POST_FILE(LUrlM,'POST',LParam);

  if not LResponse.IsEmpty then
  tmpResp := TJSON.JsonToObject<TTwitterMediaInfo>
  (LResponse,[joIgnoreEmptyArrays,joIgnoreEmptyStrings]);

  LBody    := TStringStream.Create('');
  LJsonObj := TJSONObject.Create;
  try

    LJsonObj.AddPair('text', AText);
    LJsonObj.AddPair('media',TJSONObject.Create.AddPair('media_ids',
    TJSONArray.Create.Add(tmpResp.media_id.ToString)));

    LBody.WriteString(LJsonObj.ToJSON);

    LBody.Position := 0;
    result := POST('POST',LUrl,LBody);
   except
    raise Exception.Create('Error Message');
  end;
  LBody.Free;
  LJsonObj.Free;
end;


function TTwitter.DeleteTweet(AId: string): TTweetRespDeleted;
const
  LUrl = 'https://api.twitter.com/2/tweets/';
begin
  result := nil;
  var tmpUrl := LUrl+AId;
  try
  result := DELETE(tmpUrl);
   except
    raise Exception.Create('Error Message');
  end;
end;

destructor TTwitter.Destroy;
begin
  CloseTwitterClient;
  inherited;
end;

function TTwitter.LvRequest<T>(AMethod, AUrl: String; ABody: TStringStream;
  AParams: TStringList): T;
begin
  try
    var LResponse   := POST(AMethod, AUrl,ABody);
    if not LResponse.IsEmpty then
    begin
    result := TJSON.JsonToObject<T>(LResponse,[joIgnoreEmptyArrays,joIgnoreEmptyStrings]);
    end;
  except
      on E : Exception do
      {$IFDEF VCL} ShowMessage('Error TNetHTTPClient : ' + E.Message); {$ENDIF}
      {$IFDEF FMX} ShowMessage('Error TNetHTTPClient : ' + E.Message); {$ENDIF}
  end;
end;

procedure TTwitter.SetAccessToken(const AAccessToken: String);
begin
  FAccessToken := AAccessToken;
  _AccessToken := AAccessToken;

end;

procedure TTwitter.SetBearerToken(const ABearerToken: String);
begin
  FBearerToken := ABearerToken;
  _BearerToken := ABearerToken;
end;

procedure TTwitter.SetConsumerKey(const AConsumerKey: String);
begin
  FConsumerKey := AConsumerKey;
  _ConsumerKey := AConsumerKey;
end;

procedure TTwitter.SetConsumerSecret(const AConsumerSecret: String);
begin
  FConsumerSecret := AConsumerSecret;
  _ConsumerSecret := AConsumerSecret;
end;

procedure TTwitter.SetTokenSecret(const ATokenSecret: String);
begin
 FTokenSecret := ATokenSecret;
 _TokenSecret := ATokenSecret;

end;

end.