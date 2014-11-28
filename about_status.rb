# -*- encoding : utf-8 -*-
module AboutStatus

	def self.included(base)
    base.extend(StatusClassMethods)
    base.class_eval do 
    	scope :status_not_in, lambda { |status| where(["status not in (?) ", status]) }
    end
  end

  # 拓展类方法
  module StatusClassMethods
	  # 获取状态的属性数组 i表示状态数组的维度，0按中文查找，1按数字查找
	  def get_status_attributes(status,i=0)
			arr = self.status_array
			return arr.find{|n|n[i] == status}
	  end

	  # 批量改变状态并写入日志
	  def batch_change_status_and_write_logs(id_array,status,batch_logs)
			status = self.class.get_status_attributes(status)[1] unless status.is_a?(Integer)
	    self.where(id: id_array).update_all("status = #{status}, logs = replace(logs,'</root>','  #{batch_logs.gsub('$STATUS$',status.to_s)}\n</root>')")
	  end

	end

	# 状态标签
	def status_badge(status=self.status)
		arr = self.class.get_status_attributes(status,1)
		if arr.blank?
			str = "<span class='label rounded-2x label-dark'>未知</span>"
		else
		 str = "<span class='label rounded-2x label-#{arr[2]}'>#{arr[0]}</span>"
		end
		return str.html_safe
	end

	# 状态进度条
	def status_bar(status=self.status)
		arr = self.class.get_status_attributes(status,1)
		return "" if arr.blank?
		return %Q|
		<span class='heading-xs'>#{arr[0]} <span class='pull-right'>#{arr[3]}%</span></span>
		<div class='progress progress-u progress-xs'>
		<div style='width: #{arr[3]}%' aria-valuemax='100' aria-valuemin='0' aria-valuenow='#{arr[3]}' role='progressbar' class='progress-bar progress-bar-#{arr[2]}'></div>
		</div>|.html_safe
	end

	# 更新状态并写入日志
	def change_status_and_write_logs(status,logs)
		status = self.class.get_status_attributes(status)[1] unless status.is_a?(Integer)
		self.update_columns("status" => status, "logs" => logs) unless status == self.status
	end

	# 带图标的动作
	def icon_action(action,left=true)
		key = Dictionary.icons.keys.find{|key|action.index(key)}
		icon = key ? Dictionary.icons[key] : Dictionary.icons["其他"]
		return left ? "<i class='fa #{icon}'></i> #{action}" : "#{action} <i class='fa #{icon}'></i>"
	end

end