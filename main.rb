require 'gosu'
require 'pp'
class MinesweeperTest < Gosu::Window
    def initialize
        @DIFFICULTIES = {
            beginner: [10, 10, 10],
            intermediate: [16, 16, 40],
            expert: [30, 16, 99]
        }
        @SELECTED_DIFFICULTY = :beginner
        @GRID_WIDTH, @GRID_HEIGHT, @MINES_COUNT = @DIFFICULTIES[@SELECTED_DIFFICULTY]
        @TILES_SIZE = 30
        @TILES_SPACING = 5
        @TOP_OFFSET = 40
        super @GRID_WIDTH*(@TILES_SIZE + @TILES_SPACING) + @TILES_SPACING, @GRID_HEIGHT*(@TILES_SIZE + @TILES_SPACING) + @TILES_SPACING + @TOP_OFFSET, {resizable: false}
        self.caption = "The Worst Ruby Minesweeper"
        @TILE_COLORS = {
            default: Gosu::Color.new(20,20,100),
            clear: Gosu::Color.new(100,100,100),
            mine: Gosu::Color.new(100,20,20),
            mine_win: Gosu::Color.new(20,100,20),
        }
        @FONT = Gosu::Font.new(self, Gosu::default_font_name, 30)
        @BIG_FONT = Gosu::Font.new(self, Gosu::default_font_name, 60)

        restart
    end
    
    def restart
        @game_status = :playing
        @flags_count = 0
        #create array
        @mines_map = Array.new(@GRID_WIDTH).map{Array.new(@GRID_HEIGHT)}
        @MINES_COUNT.times do
            loop do
                x = rand @GRID_WIDTH
                y = rand @GRID_HEIGHT
                next if @mines_map[x][y]
                @mines_map[x][y] = :mine
                break
            end
        end
        #proximity map
        @proximity_map = Array.new(@GRID_WIDTH).map{Array.new(@GRID_HEIGHT)}
        @GRID_WIDTH.times do |x|
            @GRID_HEIGHT.times do |y|
                rel_count = 0
                3.times do |x_off|
                    next unless @mines_map[x + x_off - 1]
                    3.times do |y_off|
                        tile = @mines_map[x + x_off - 1][y + y_off - 1]
                        rel_count+=1 if tile && tile == :mine
                    end
                end
                @proximity_map[x][y] = rel_count
            end
        end
        #flags map
        @flags_map = Array.new(@GRID_WIDTH).map{Array.new(@GRID_HEIGHT).fill(false)}
    end

    def update

    end
    
    def draw
        @GRID_WIDTH.times do |x|
            x_pos = x*(@TILES_SIZE) + @TILES_SPACING*(x+1)
            @GRID_HEIGHT.times do |y|
                y_pos = y*(@TILES_SIZE) + @TILES_SPACING*(y+1) + @TOP_OFFSET
                tile_content = @mines_map[x][y]
                # tile_type = :mine if tile_content == :mine
                
                tile_type = :mine if tile_content == :mine && @game_status == :lost
                tile_type = :mine_win if tile_content == :mine && @game_status == :won
                
                tile_type = :clear if tile_content == :clear
                tile_type = :default unless tile_type 

                draw_rect(x_pos,y_pos,@TILES_SIZE,@TILES_SIZE,@TILE_COLORS[tile_type])

                #number
                @FONT.draw_text(@proximity_map[x][y], x_pos + 8, y_pos + 2, 0) if @proximity_map[x][y] && tile_type == :clear && @proximity_map[x][y] != 0

                #flag
                @FONT.draw_text("🚩F", x_pos + 8, y_pos + 2, 0) if @flags_map[x][y] && tile_type == :default
                
                #info
                @FONT.draw_text("🚩F #{(@MINES_COUNT - @flags_count)}", self.width - 70, 8, 0)
                
                @BIG_FONT.draw_text("PERDU! (f5)", 40, (@GRID_HEIGHT * (@TILES_SIZE + @TILES_SPACING))/2 - 30, 0, 1, 1, Gosu::Color.new(255, 0, 0)) if @game_status == :lost
                @BIG_FONT.draw_text("GAGNÉ! (f5)", 40, (@GRID_HEIGHT * (@TILES_SIZE + @TILES_SPACING))/2 - 30, 0, 1, 1, Gosu::Color.new(0, 255, 0)) if @game_status == :won
            end
        end
    end
    def needs_cursor?
        true
    end
    def button_down key
        super key
        on_mouse_down key if key >= Gosu::MsLeft && key <= Gosu::MsRight
        restart if key == Gosu::KB_F5
    end
    def on_mouse_down key
        tile_x = (mouse_x / (@TILES_SIZE + @TILES_SPACING)).floor
        tile_y = ((mouse_y - @TOP_OFFSET) / (@TILES_SIZE + @TILES_SPACING)).floor
        # puts "x: #{tile_x}, y: #{tile_y}"
        return if tile_x < 0 || tile_x >= @GRID_WIDTH || tile_y < 0 || tile_y >= @GRID_HEIGHT
        clear_tile(tile_x, tile_y) if key == Gosu::MsLeft
        toggle_flag(tile_x, tile_y) if key == Gosu::MsRight
        # restart unless @game_status == :playing
    end
    def toggle_flag x, y
        return unless @game_status == :playing
        return unless @mines_map[x][y] == nil || @mines_map[x][y] == :mine #Bricolo mondo
        @flags_map[x][y] = !@flags_map[x][y]
        @flags_count = get_count_in_array(@flags_map, true)
    end
    def clear_tile x, y
        return unless @game_status == :playing
        return if @mines_map[x][y] == :clear
        return end_game if @mines_map[x][y] == :mine
        soft_clear x, y, true

        return end_game(:won) if (@GRID_WIDTH * @GRID_HEIGHT - get_count_in_array(@mines_map, :clear)) == @MINES_COUNT
    end
    def soft_clear x, y, force = false, propagate = :all
        return unless x.between?(0, @GRID_WIDTH - 1) && y.between?(0, @GRID_HEIGHT - 1)
        return if @mines_map[x][y] == :mine
        return if @flags_map[x][y]
        return unless @proximity_map[x][y] || !force
        @mines_map[x][y] = :clear
        next_positions = case propagate
            when :all then [[-1, 0, :left_all], [1, 0, :right_all], [0, 1, :up], [0, -1, :down]]
            when :left_all then [[-1, 0, :left_all], [0, 1, :up], [0, -1, :down]]
            when :right_all then [[1, 0, :right_all], [0, 1, :up], [0, -1, :down]]
            when :up then [[0, 1, :up]]
            when :down then [[0, -1, :down]]
        end
        next_positions.each do |next_pos|
            next_pos_x, next_pos_y, propagation_dir = next_pos
            soft_clear(next_pos_x + x, next_pos_y + y, false, propagation_dir)
        end
    end
    def end_game state = :lost
        @game_status = state
    end
    def get_count_in_array array, data_val
        array.reduce(0){|sum, data| sum + data.count(data_val)}
    end
end
MinesweeperTest.new.show