require 'dxruby'
require_relative 'ev3/ev3'

class Carrier
	#インスタンス変数
	LEFT_MOTOR = "A"
	RIGHT_MOTOR = "D"
	CENTOR_ARM = "B"
	PORT = "COM3"
	wheel_motors = [LEFT_MOTOR,RIGHT_MOTOR]

	#アクセサメソッド
	attr_reader :distance

	#初期化
	def initialize
		@brick = EV3::Brick.new(EV3::Connections::Bluetooth.new(PORT))
		@brick.connect
		@busy = false
		@distance=0

	end

	#これ何？
	def all_motors
		@all_motors ||= self.class.constants.grep(/_MOTOR\z/).map{|c| self.class.const_get(c) }
	end

	#壁を下す
	#   def down_wall(speed=MOTOR_SPEED)
	#   operate do
	#     @brick.start(speed, *wheel_motors)
	#   end

	#アーム下し
	def arm_down(*mota)
		@brick.run_forward(*mota)
		@brick.step_velocity(30, 85, 5 ,*mota)
		@brick.motor_ready(*mota)
		@brick.reset(*mota)
	end

	#角度で腕を上下
	def arm_updown(vel, deg, slow)
		@brick.run_forward(CENTOR_ARM)
		@brick.step_velocity(vel, deg, slow, CENTOR_ARM)
		@brick.motor_ready(CENTOR_ARM)
		@brick.reverse_polarity(CENTOR_ARM)
		@brick.step_velocity(vel, deg, slow, CENTOR_ARM)
		@brick.motor_ready(CENTOR_ARM)
	end

	#センサ更新
	def update
		@distance = @brick.get_sensor(SENSOR, 0)
	end

	#動きを止める
	def stop
		@brick.stop(true, *all_motors)
		@brick.run_forward(*all_motors)
		@busy = false
	end

	#重なり回避
	def operate
		unless @busy
			@busy = true
			yield(@brick)
		end
	end

	#終了処理
	def close
		stop
		@brick.clear_all
		@brick.disconnect
	end

	def wheel_motors
		[LEFT_MOTOR,RIGHT_MOTOR]
	end
end

#main
begin
	puts "starting..."
	carrier = Carrier.new
	carrier.arm_down(*carrier.wheel_motors)

	Window.loop do
		break if Input.keyDown?(K_SPACE)
		carrier.arm_updown(30, 85, 5)
	end
	carrier.stop
rescue
	p $!
	$!.backtrace.each{|trace| puts trace}
# 終了処理は必ず実行する
ensure
	puts "closing..."
	carrier.close
	puts "finished..."

end
