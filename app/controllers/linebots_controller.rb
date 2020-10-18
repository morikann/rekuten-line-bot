class LinebotsController < ApplicationController
  require 'line/bot'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery except: [:callback]

  def callback
    # railsではjsonをPOSTで受け取る場合、よしなにparamsの配列に入れてくれる。だが、jsonのstringそのものが欲しい場合がある。
    # その時にrequest.body.readを使うことによってbodyのままのStringが取得できる。
    body = request.body.read 
    # X-Line-Signatureリクエストヘッダーに含まれる署名を検証して、リクエストがlineのプラットフォームから送られたことを確認する
    # 要するに（それぞれのユーザーの）Lineから送られてきていることを確認する
    signature = request.env['HTTP_X_LINE_SIGNATURE'] 
    # validate_signature メソッド -> https://github.com/line/line-bot-sdk-ruby/blob/master/lib/line/bot/client.rb 
    unless client.validate_signature(body, signature)
      # headメソッドを使うことでヘッダだけで本文（body）のないレスポンスをブラウザに送信できる。
      # 以下のコードはエラーヘッダーのみのレスポンスを返す。
      return head :bad_request
    end
    # parse_events_from メソッド -> https://github.com/line/line-bot-sdk-ruby/blob/master/lib/line/bot/client.rb
    events = client.parse_events_from(body)
    events.each do |event|
      case event
      # モジュール -> https://github.com/line/line-bot-sdk-ruby/blob/master/lib/line/bot/event/message.rb
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          # 入力した文字をinputに格納
          input = event.message['text']
          # search_and_create_messageメソッド内で楽天APIを用いた商品検索、メッセージの作成を行う
          message = search_and_create_message(input)
          client.reply_message(event['replyToken'], message)
        end
      end
    end
    head :ok
  end


  private
    
    def client
      # モジュールの名前空間::を使っている。Client class -> https://github.com/line/line-bot-sdk-ruby/blob/master/lib/line/bot/client.rb 
      @client ||= Line::Bot::Client.new do |config|
        config.channel_select = ENV['LINE_BOT_CHANNEL_SECRET']
        config.channel_token = ENV['LINE_BOT_CHANNEL_TOKEN']
      end
    end

    def search_and_create_message
      # 楽天のSDK
      RakutenWebService.configure do |c|
        c.application_id = ENV['RAKUTEN_APPID']
        c.affiliate_id = ENV['RAKUTEN_AFID']
      end

      # 楽天の商品検索APIで画像がある商品の中で、入力値で検索して上から3件を取得する
      # 商品検索+ランキングでの取得はできないため標準の並び順で上から3件取得する
      res = RakutenWebService::Ichiba::Item.search(keyword: input, hits: 3, imageFlag: 1)
      items = []
      # 取得したデータを使いやすいように配列に格納し直す
      items = res.map{ |item| item }
      make_reply_content(items)
    end

    def make_reply_content(items)
      {
        "type": "flex",
        "altText": "This is a Flex Message",
        "contents": 
        {
          "type": "carousel",
          "contents": [
            make_part(items[0]),
            make_part(items[1]),
            make_part(items[2])
          ]
        }
      }
    end

    def make_part(item)
      title = item['itemName']
      price = item['itemPrice'].to_s + '円'
      url = item['itemUrl']
      image = item['mediumImageUrls'].first
      {
        "type": "bubble",
        "hero": {
          "type": "image",
          "size": "full",
          "aspectRatio": "20:13",
          "aspectMode": "cover",
          "url": image
        },
        "body":
        {
          "type": "box",
          "layout": "vertical",
          "spacing": "sm",
          "contents": [
            {
              "type": "text",
              "text": title,
              "wrap": true,
              "weight": "bold",
              "size": "lg"
            },
            {
              "type": "box",
              "layout": "baseline",
              "contents": [
                {
                  "type": "text",
                  "text": price,
                  "wrap": true,
                  "weight": "bold",
                  "flex": 0
                }
              ]
            }
          ]
        },
        "footer": {
          "type": "box",
          "layout": "vertical",
          "spacing": "sm",
          "contents": [
            {
              "type": "button",
              "style": "primary",
              "action": {
                "type": "uri",
                "label": "楽天市場商品ページへ",
                "uri": url
              }
            }
          ]
        }
      }
    end
end
