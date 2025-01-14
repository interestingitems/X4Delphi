{*******************************************************************************
  *                                                                             *
  *   Delphi Twitter (X) Library                                                *
  *                                                                             *
  *   Developer: Silas AIKO                                                     *
  *                                                                             *
  *   Description:                                                              *
  *   This Delphi library provides functionality for interacting with the       *
  *   Twitter (X) API v1 and v2.                                                *
  *                                                                             *
  *   Compatibility: VCL, FMX                                                   *
  *   Tested on Delphi: 11 Alexandria  CE                                       *
  *   Version: 1.1.0                                                            *
  *                                                                             *
  *   License: MIT License (See LICENSE file for details)                       *
  *                                                                             *
  *                                                                             *
  *******************************************************************************}

unit Twitter.Client;

interface

uses
  System.SysUtils, System.Classes, Twitter.Core, Twitter.Api.Types,
  Json, REST.Json,System.Net.Mime,FMX.Dialogs,
  // Indy
  IdContext,IdBaseComponent, IdComponent, IdCustomTCPServer, IdCustomHTTPServer,
  IdHTTPServer,IdServerIOHandler,IdServerIOHandlerSocket,IdServerIOHandlerStack;

type

  TTwitterAuthEvent = procedure (AIsAuth : boolean) of object;
  TTwitterTweetSent = procedure (ATweetId: string; ATweet:String) of object;
  TTwitterTweetSentContent = procedure (ATweetMediaId: string) of object;

  TTwitter = class(TComponent)
  private

    FConsumerKey   : string;
    FConsumerSecret: string;
    FAccessToken   : string;
    FTokenSecret   : string;
    FBearerToken   : string;
    FCallBack      : TIdHTTPServer;
    FTwitterAuth   : TTwitterAuthEvent;
    FTweetSent     : TTwitterTweetSent;
    FTweetSentContent : TTwitterTweetSentContent;

    procedure SetConsumerKey   (const AConsumerKey :String);
    procedure SetConsumerSecret(const AConsumerSecret :String);
    procedure SetAccessToken   (const AAccessToken :String);
    procedure SetTokenSecret   (const ATokenSecret :String);
    procedure SetBearerToken   (const ABearerToken :String);

    procedure HandleCallbackRequest(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);

    function  LvRequest <T:class,constructor>(AMethod, AUrl: String; ABody: TStringStream; AParams : TStringList=nil):T;
    function  RedirectUser (AUrl:string): Boolean;

  protected
    procedure IsAuthenticated(AState:Boolean);
    procedure TweetSent(ATweetId : string; ATweetText: string);
    procedure TweetSentContent(ATweetMediaId : string);

  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;

    procedure CreateTweet(AText: String);
    procedure CreateTweetWithContent(AText: String; AMedia:String);
    procedure SignIn;

    function DeleteTweet(AId: string): TTweetRespDeleted;

  published

    property ConsumerKey    : String  read FConsumerKey      write SetConsumerKey;
    property ConsumerSecret : String  read FConsumerSecret   write SetConsumerSecret;
    property AccessToken    : String  read FAccessToken      write SetAccessToken;
    property TokenSecret    : String  read FTokenSecret      write SetTokenSecret;
    property BearerToken    : String  read FBearerToken      write SetBearerToken;

    property OnAuthenticated        : TTwitterAuthEvent        read FTwitterAuth      write FTwitterAuth;
    property OnTweetSent            : TTwitterTweetSent        read FTweetSent        write FTweetSent;
    property OnTweetSentWithContent : TTwitterTweetSentContent read FTweetSentContent write FTweetSentContent;

  end;

procedure Register;

implementation

uses ShellAPI, Windows;


procedure Register;
begin
  RegisterComponents('Bunker X', [TTwitter]);
end;

{ TTwitter }

constructor TTwitter.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
end;

procedure TTwitter.CreateTweet(AText: String);
var
  LBody    : TStringStream;
  LJsonObj : TJSONObject;
begin
  LBody    := TStringStream.Create('');
  LJsonObj := TJSONObject.Create;
  try
    LJsonObj.AddPair('text', AText);
    LBody.WriteString(LJsonObj.ToJSON);
    LBody.Position := 0;
    ClientBase.ContentType  := 'application/json';
    var LObj:= LvRequest<TTweetResponse>('POST',LUrl,LBody);
    if not (LObj.data.id.IsEmpty) then
    TweetSent(LObj.data.id,LObj.data.text);
   except
    raise Exception.Create('Error Message');
  end;
  LBody.Free;
  LJsonObj.Free;
end;

procedure TTwitter.CreateTweetWithContent(AText, AMedia: String);
var
  LBody    : TStringStream;
  LJsonObj : TJSONObject;
  LParam   : TMultipartFormData;
  LTmpObj  : TTwitterMediaInfo;
begin
  LTmpObj := TTwitterMediaInfo.Create;
  LParam  := TMultipartFormData.Create;
   try
      LParam.AddFile('media',AMedia);
      var LResponse := POST_FILE(LUrlM,'POST',LParam);

      if not (LResponse.IsEmpty) then
      begin
        LTmpObj := TJSON.JsonToObject<TTwitterMediaInfo>
      (LResponse,[joIgnoreEmptyArrays,joIgnoreEmptyStrings]);
      end;

      var LFlag := LTmpObj.image.image_type;
      if not (LTmpObj.media_id_string.IsEmpty) then
      begin
        LBody    := TStringStream.Create('');
        LJsonObj := TJSONObject.Create;
        try
          LJsonObj.AddPair('text', AText);
          LJsonObj.AddPair('media',TJSONObject.Create.AddPair('media_ids',
          TJSONArray.Create.Add(LTmpObj.media_id.ToString)));

          LBody.WriteString(LJsonObj.ToJSON);

          LBody.Position := 0 ;
          LResponse := POST('POST',LUrl,LBody);
          if not LResponse.IsEmpty then
          begin
            var Resp := TJSON.JsonToObject<TTweetResponse>
           (LResponse,[joIgnoreEmptyArrays,joIgnoreEmptyStrings]);
            LFlag := Resp.data.id;
            TweetSentContent(LFlag);
          end
         except
          raise Exception.Create('Error Message');
        end;
        LBody.Free;
        LJsonObj.Free;
      end;
   except
    raise Exception.Create('Error Message');
   end;
end;

function TTwitter.DeleteTweet(AId: string): TTweetRespDeleted;
begin
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


procedure TTwitter.HandleCallbackRequest(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  Params: TStringList;
begin
  if URLContains(ARequestInfo.QueryParams) then FCallBack.DisposeOf;
  if ARequestInfo.URI = '/auth/twitter/callback' then
  begin
    Params := TStringList.Create;

        Params.Delimiter := '&';
        Params.StrictDelimiter := True;
        Params.DelimitedText := ARequestInfo.QueryParams;
        LRespToken.oauth_verifier := Params.Values['oauth_verifier'];

        if (LRespToken.oauth_token = Params.Values['oauth_token']) then
        begin

           Params.Clear;
           Params.AddPair('oauth_verifier',LRespToken.oauth_verifier);
           Params.AddPair('oauth_token',LRespToken.oauth_token);
           
           Params.DelimitedText := POST('POST',LtmpUrl,nil,Params);

           User._AccessToken := Params.Values['oauth_token'];
           User._TokenSecret := Params.Values['oauth_token_secret'];
           User._UserID      := Params.Values['user_id'];
           User._ScreenName  := Params.Values['screen_name'];

           AResponseInfo.ResponseText := 'You are authenticated !';

           TThread.Synchronize(nil,
           procedure
           begin
            IsAuthenticated(True);
           end);

         end else AResponseInfo.ResponseNo := 404;

         FCallBack.StopListening;

  end else
  begin
    IsAuthenticated(False);
    AResponseInfo.ResponseNo := 404;
    FCallBack.DisposeOf;
  end;

end;

procedure TTwitter.IsAuthenticated(AState: Boolean);
begin
  if Assigned(FTwitterAuth) then FTwitterAuth(AState);
end;

function TTwitter.LvRequest<T>(AMethod, AUrl: String; ABody: TStringStream;
  AParams: TStringList): T;
begin
  result := nil;
  try
    var LResponse   := POST(AMethod, AUrl,ABody,nil);
    if not LResponse.IsEmpty then
    result := TJSON.JsonToObject<T>(LResponse,[joIgnoreEmptyArrays,joIgnoreEmptyStrings]);
  except
      on E : Exception do
      {$IFDEF VCL} ShowMessage('Error TNetHTTPClient : ' + E.Message); {$ENDIF}
      {$IFDEF FMX} ShowMessage('Error TNetHTTPClient : ' + E.Message); {$ENDIF}
  end;
end;

function TTwitter.RedirectUser(AUrl: string): Boolean;
var
  HInst: NativeUInt;
begin
{$IFDEF MSWINDOWS}
  HInst := ShellExecute(0, 'open', PChar(AUrl), nil, nil, SW_SHOWNORMAL);
  Result := (HInst>32) or (HInst = SE_ERR_NOASSOC);
{$ENDIF}
 end;

procedure TTwitter.SetAccessToken(const AAccessToken: String);
begin
  FAccessToken      := AAccessToken;
  User._AccessToken := AAccessToken;
end;

procedure TTwitter.SetBearerToken(const ABearerToken: String);
begin
  FBearerToken      := ABearerToken;
  User._BearerToken := ABearerToken;
end;



procedure TTwitter.SetConsumerKey(const AConsumerKey: String);
begin
  FConsumerKey      := AConsumerKey;
  User._ConsumerKey := AConsumerKey;
end;

procedure TTwitter.SetConsumerSecret(const AConsumerSecret: String);
begin
  FConsumerSecret      := AConsumerSecret;
  User._ConsumerSecret := AConsumerSecret;
end;


procedure TTwitter.SetTokenSecret(const ATokenSecret: String);
begin
 FTokenSecret      := ATokenSecret;
 User._TokenSecret := ATokenSecret;
end;

procedure TTwitter.SignIn ;
var
  LParam            : TStringList;
  Resp, RedirectURL : string;
begin

  LParam := TStringList.Create;
  LParam.Delimiter := '&';
  LParam.StrictDelimiter := true;

  try
    Resp := POST('POST',LUrlAuth,nil);
    if Resp.IsEmpty then exit;
    LParam.DelimitedText   := Resp;

    LRespToken.oauth_token        := LParam.Values['oauth_token'];
    LRespToken.oauth_token_secret := LParam.Values['oauth_token_secret'];
    LRespToken.oauth_callbackcf   := LParam.Values['oauth_callback_confirmed'].ToBoolean;

    if LRespToken.oauth_callbackcf then
    begin
          FCallBack := TIdHTTPServer.Create(Self);
        try
          FCallBack.DefaultPort  := ADefault;
          FCallBack.OnCommandGet := HandleCallbackRequest;
          FCallBack.Active := True;
          RedirectURL := Format('%s?%s',[LRedirect,LParam.DelimitedText]);
          RedirectUser(RedirectURL);
        except
          on Exception do FCallBack.Free;
        end;
    end;
   except
    raise Exception.Create('Error Message');
  end;
  LParam.Free;
end;


procedure TTwitter.TweetSent(ATweetId, ATweetText: string);
begin
  if Assigned(FTweetSent) then FTweetSent(ATweetId, ATweetText);
end;

procedure TTwitter.TweetSentContent(ATweetMediaId: string);
begin
  if Assigned(FTweetSentContent) then FTweetSentContent(ATweetMediaId);
end;

end.
