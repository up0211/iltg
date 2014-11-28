# -*- encoding : utf-8 -*-
class SingleForm < MyForm

	attr_accessor :options, :rules, :messages, :html_code
	attr_reader :xml, :obj, :table_name

	def initialize(xml,obj,options={})
		@xml = xml
		@obj = obj
		@options = options
		@table_name = obj.class.to_s.tableize
		@rules = []
		@messages = []
		@html_code = ""
		@options[:grid] ||= 1
		@options[:form_id] ||= "myform" 
    @options[:action] ||= "" 
    @options[:method] ||= "post"
    @options[:button] = true if @options[:button].nil?
	end

	# def get_input_part
 #  	self.get_input_str
 #  end

end