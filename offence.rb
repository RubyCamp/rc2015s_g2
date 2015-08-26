require 'dxruby'
require_relative 'ev3/ev3'

class Crab
	#インスタンス変数
	RIGHT_MOTOR = "A"	#右モータ
 	LEFT_MOTOR = "D"	#左モータ
 	FAN_MOTOR = "B"		#中央モータ(ファン)
 	PORT = "COM3"		#接続ポート
 	RIGHT_DISTANCE_SENSOR = "1"		#右超音波センサ
 	LEFT_DISTANCE_SENSOR = "4"		#左超音波センサ
 	AUTO_WHEEL_SPEED = 20		#オート時スピード
 	MANUAL_WHEEL_SPEED = 50		#マニュアル時スピード
 	FAN_SPEED = 100				#ファンスピード
 	#本体移動用モータ
 	MOVE_MOTORS = [RIGHT_MOTOR, LEFT_MOTOR]
 	#接続済モータ
 	ALL_MOTORS = [RIGHT_MOTOR, LEFT_MOTOR,FAN_MOTOR]
 	#全超音波センサ
 	ALL_DISTANCE_SENSORS = [RIGHT_DISTANCE_SENSOR, LEFT_DISTANCE_SENSOR]

 	#壁との距離保存

 	attr_reader :right_distance, :left_distance
 	#モータ回転の場面
 	#正面から、0:左進行 1:右進行
 	attr_accessor :seen

 	#初期化
	def initialize
		@brick = EV3::Brick.new(EV3::Connections::Bluetooth.new(PORT))
		@brick.connect
		@busy = false
	end

	#右に進む
	def run_right( speed = AUTO_WHEEL_SPEED )
		operate do
			@brick.reverse_polarity(RIGHT_MOTOR)
			@brick.start(speed, *MOVE_MOTORS)
		end
	end

	#左に進む
	def run_left( speed = AUTO_WHEEL_SPEED )
		operate do
			@brick.reverse_polarity(LEFT_MOTOR)
			@brick.start(speed, *MOVE_MOTORS)
		end
	end

	#移動モータの反転
	def reverce_motor
		@brick.reverse_polarity(*MOVE_MOTORS)
	end

	#ファンの処理
	def fan_rotate( speed = FAN_SPEED)
		@brick.start(speed,FAN_MOTOR)
	end

	#全モータの動きを止める
	def all_stop
		@brick.stop(true, *ALL_MOTORS)
		@brick.run_forward(*ALL_MOTORS)
		@busy = false
	end

	#移動モータの動きを止める
	def move_stop
		@brick.stop(true, *MOVE_MOTORS)
		@brick.run_forward(*MOVE_MOTORS)
		@busy = false
	end

	#センサー情報の更新
	def update
		@right_distance = @brick.get_sensor(RIGHT_DISTANCE_SENSOR, 0)
		@left_distance = @brick.get_sensor(LEFT_DISTANCE_SENSOR, 0)
	end

	#終了処理
	def close
		all_stop
		@brick.clear_all
		@brick.disconnect
	end

	#ある動作中は別の動作を受け付けないようにする
	def operate
		unless @busy
			@busy = true
			yield(@brick)
		end
	end

	#自動処理
	def auto_run
		#距離センサが壁を感知した時の処理
		if @left_distance<5.0 && @seen==0 then
			#seen変更
			@seen=1

			#ゆとり
			move_stop
			run_right
			sleep 0.5
		elsif @right_distance<5.0 && @seen==1 then
			#seen変更
			@seen=0

			#ゆとり
			move_stop
			run_left
			sleep 0.5
		#通常時移動
		#seen=0は正面から見て右寄せ
		#つまり、左動き
		elsif @seen == 0 then
			run_left
		#seen=1は正面から見て左寄せ
		#つまり、右動き
		elsif @seen == 1 then
			run_right
		end
	end

	#手動操作
	def manual_run
		if Input.keyDown?(K_RIGHT)
			@seen = 1
			run_right
		end
		if Input.keyDown?(K_LEFT)
			@seen = 0
			run_left
		end
		move_stop if [K_LEFT, K_RIGHT].all?{|key| !Input.keyDown?(key) }
	end
end

begin
	#初期化
	puts "starting..."
	font = Font.new(32)
	crab = Crab.new
	puts "connected..."
	crab.seen=0
	#手動 or 自動
	#0:自動 1:手動
	control = 0

	#mainループ
	Window.loop do
		#終了条件
		break if Input.keyDown?( K_SPACE )

		#センサ更新
		crab.update

		#モード切替
		if Input.keyDown?( K_RETURN ) then
			if control == 0 then
				control = 1
				crab.move_stop
			else
				control = 0
			end
		end

		#情報表示
		Window.draw_font(100, 100, "control = #{control}", font)
		Window.draw_font(100, 150, "seen = #{crab.seen}", font)
		Window.draw_font(100, 200, "R: #{crab.right_distance.to_i}cm", font)
		Window.draw_font(100, 250, "L: #{crab.left_distance.to_i}cm", font)

		#機械稼働
		crab.fan_rotate
		if control == 0 then
		 	crab.auto_run
		elsif control == 1 then
		 	crab.manual_run
		end
	end
rescue
	p $!
	$!.backtrace.each{|trace| puts trace}
#終了処理は必ず実行する
ensure
	puts "closing..."
	crab.close
	puts "finished..."
end