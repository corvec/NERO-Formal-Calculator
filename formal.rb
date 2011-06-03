#!/usr/bin/env ruby

require 'rubygems'
require 'Qt4'
require 'yaml'


class FormalGUI < Qt::Widget
	def initialize parent=nil
		super parent
		self.windowTitle = 'Magic Item Cost Calculator'
		layout = Qt::GridLayout.new self

		################################
		## Cost Banner
		################################
		@costbanner = Qt::Label.new 'Cost in Staff Points: 0'

		#############################
		## Effects Frame
		#############################
		effects_frame = Qt::Frame.new
		effects_frame.frameShadow = Qt::Frame::Raised
		effects_frame.frameShape = Qt::Frame::StyledPanel
		effects_layout = Qt::GridLayout.new(effects_frame)

		effects_layout.addWidget Qt::Label.new('Effect'), 0, 0
		effects_layout.addWidget Qt::Label.new('Level'),  0, 1

		ritual_names = []
		File.open('rituals') { |file|
			while line = file.gets
				ritual_names << line.strip
			end
		}
		ritual_name_completer = Qt::Completer.new(ritual_names)
		ritual_name_completer.completionMode = Qt::Completer::UnfilteredPopupCompletion
		@effect_name_text  = []
		@effect_level_text = []
		(0..4).each do |i|
			@effect_name_text << Qt::ComboBox.new(nil)
			@effect_name_text[i].addItem ''
			@effect_name_text[i].addItems ritual_names
			@effect_name_text[i].connect(SIGNAL('currentIndexChanged(int)')) { |foo|
				self.update_cost
			}
			@effect_level_text << Qt::LineEdit.new(nil)
			@effect_level_text[i].connect(SIGNAL(:editingFinished)) {
				self.update_cost()
			}
			effects_layout.addWidget(@effect_name_text[i],  i + 1, 0)
			effects_layout.addWidget(@effect_level_text[i], i + 1, 1)
		end

		##########################
		## Info Frame
		##########################

		info_frame = Qt::Frame.new
		info_frame.frameShadow = Qt::Frame::Raised
		info_frame.frameShape = Qt::Frame::StyledPanel
		info_layout = Qt::VBoxLayout.new(info_frame)

		#info_layout.addWidget Qt::Label.new('Render:'),0,0
		@render_check_box = Qt::CheckBox.new 'Render:', nil
		@render_check_box.connect(SIGNAL(:released)) {
			self.update_cost
		}
		info_layout.addWidget @render_check_box
		info_layout.addWidget Qt::Label.new('Earth Extension')

		@earth_extension_text = Qt::ComboBox.new()
		@earth_extension_text.addItems ['5 Days','6 Month','1 Year','2 Year']
		@earth_extension_text.connect(SIGNAL('currentIndexChanged(int)')) { |foo|
			self.update_cost
		}
		info_layout.addWidget @earth_extension_text

		info_layout.addWidget Qt::Label.new('Celestial Extension')

		@celestial_extension_text = Qt::ComboBox.new(nil)
		@celestial_extension_text.addItems ['5 Days','6 Month','1 Year','2 Year']
		@celestial_extension_text.connect(SIGNAL('currentIndexChanged(int)')) { |foo|
			self.update_cost
		}
		info_layout.addWidget @celestial_extension_text

		layout.addWidget(@costbanner,0,0,1,2)
		layout.addWidget(effects_frame,1,0)
		layout.addWidget(info_frame,1,1)
	end

	def get_effects
		effect_list = []
		@effect_name_text.each_with_index do |effect,i|
			if effect.currentText != ''
				effect_list << [effect.currentText,@effect_level_text[i].text.to_i,1]
			end
		end

		effects = {}
		
		

		#effects = {'Damage Aura' => 3, 'Spirit Link' => [0], 'Expanded Enchantment' => [3,9]}
		effect_list.each do |effect_data|
			if ['Damage Aura','Spell Store','Store Ability'].include? effect_data[0]
				if effects.has_key? effect_data[0]
					case effects[effect_data[0]]
					when 1
						effects[effect_data[0]] += 2
					when 3
						effects[effect_data[0]] += 3
					when 6
						effects[effect_data[0]] += 4
					end
				else
					effects[effect_data[0]] = 1
				end
			else
				if effects.has_key? effect_data[0]
					effects[effect_data[0]] << effect_data[1]
				else
					effects[effect_data[0]] = [effect_data[1]]
				end
			end
		end
		#effects = {'Damage Aura' => 3, 'Spirit Link' => 1, 'Expanded Enchantment' => [3,9]}

		return_data = {}
		effects.each do |effect,data|
			if data.is_a? Array
				# Everything except for stuff that pyramids:
				# Includes things like expanded enchantments
				rit_count = [0] * 10
				data.each do |i|
					rit_count[i] += 1
				end
				rit_count.each_with_index do |count, level|
					if count > 0
						return_data[Ritual.new(effect,level)] = count
					end
				end
			else
				# For stuff like Damage Aura and other things like that...
				return_data[Ritual.new(effect)] = data
			end
		end

		if @render_check_box.isChecked
			return_data[Ritual.new('Render Indestructible')] = 1
		end

		case @earth_extension_text.currentText
		when '6 Month'
			return_data[Ritual.new('Extend Enchantment')] = 1
		when '1 Year'
			return_data[Ritual.new('Extend Formal Magic')] = 1
		when '2 Year'
			return_data[Ritual.new('Greater Extension')] = 1
		end

		case @celestial_extension_text.currentText
		when '6 Month'
			return_data[Ritual.new('Extend Enchantment')] = 1
		when '1 Year'
			return_data[Ritual.new('Extend Formal Magic')] = 1
		when '2 Year'
			return_data[Ritual.new('Greater Extension')] = 1
		end

		return return_data
	end
	def update_cost
		cost = 0

		effects = self.get_effects

		item = MagicItem.new('Magic Item',effects)
		puts
    puts item
		@costbanner.text= "Cost in Staff Points: #{item.cost}"
	end
end

class MagicItem
	def initialize( name, effects = {} )
		@name    = name
		@effects = effects
	end

	def add_effect effect, count = 1
		if !effect.is_a? Ritual
			effect = $ritual_data.get_ritual(effect)
		end
		@effects[effect] = count
	end

	def effects
		@effects.clone
	end

	def cost
		c = 0
		@effects.each do |effect, count|
			c += effect.cost * count
		end
		c
	end

	def to_s
		s  = "#{@name} (Costs: #{self.cost()})\n"
		@effects.each do |effect, count|
			s += "#{effect.to_s}: #{count} x #{effect.cost} = #{count * effect.cost}\n"
		end
		return s
	end
end

class Ritual
	attr_reader :name, :components, :school, :level
	def initialize(name, spell_level = 0)
		if !$ritual_data.has_key? name
			puts "Database does not have data on the ritual '#{name}'"
		end
		@name        = name
		@spell_level = spell_level
		@components  = $ritual_data[name]['Components']
		@level       = $ritual_data[name]['Level']
	end

	def to_s
		result = @name
		if @spell_level != 0
			result += "(#{@spell_level})"
		end

		return result
	end

	def cost
		total = @level
		@components.each do |c,amount|
			if !amount.is_a?(Integer)
				case amount
				when 'Level'
					amount = @spell_level
				when 'Half Level'
					amount = 1 + (@spell_level - 1) / 2
				else
					amount = 0
				end
			end
			total += amount * $component_data[c][:cost]
		end

		return total
	end
end


class ComponentData
	def initialize
		@data = {
			'P' => {:cost => 3},
			'C' => {:cost => 2},
			'D' => {:cost => 2},
			'E' => {:cost => 2},
			'S' => {:cost => 2},
			'T' => {:cost => 2},
			'V' => {:cost => 2},
			'P2' => {:cost => 10}
		}
	end
	def [](i)
		@data[i]
	end
end

class RitualData
	def initialize
		@data = YAML.load(File.new('rituals.yml'))
	end

	def [](i)
		@data[i]
	end

	def has_key? i
		@data.has_key? i
	end

	def get_ritual ritual_name
		Ritual.new(ritual_name)
	end

end

$ritual_data    = RitualData.new()
$component_data = ComponentData.new()

def test
	spear = MagicItem.new("Avadur's Cool Spear")
	enchantment = Ritual.new('Expanded Enchantment',4)
	spear.add_effect(enchantment,2)
	enchantment = Ritual.new('Expanded Enchantment',9)
	spear.add_effect(enchantment,2)
	spear.add_effect('Spirit Link')
	spear.add_effect('Render Indestructible')
	spear.add_effect('Extend Formal Magic')
	puts spear
	
	pants = MagicItem.new("Hedgehog's Pants")
	enchantment = Ritual.new('Expanded Enchantment',4)
	pants.add_effect(enchantment)
	enchantment = Ritual.new('Expanded Enchantment',5)
	pants.add_effect(enchantment)
	enchantment = Ritual.new('Expanded Enchantment',8)
	pants.add_effect(enchantment)
	enchantment = Ritual.new('Expanded Enchantment',9)
	pants.add_effect(enchantment)
	pants.add_effect('Render Indestructible')
	pants.add_effect("Spirit Link")
	pants.add_effect('Greater Extension')
	puts pants
	
	sword = MagicItem.new("Rynn's Sword")
	sword.add_effect('Damage Aura', 3)
	sword.add_effect('Greater Extension')
	sword.add_effect('Render Indestructible')
	puts sword
end

if __FILE__ == $0
  app = Qt::Application.new ARGV
	frame = FormalGUI.new
	frame.show
	app.exec
end
