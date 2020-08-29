require 'gosu'
require 'pp'
class MinesweeperTest < Gosu::Window
    def initialize
        @SELECTED_DIFFICULTY = :beginner
        @DIFFICULTIES = {
            beginner: [10, 10, 10],
            intermediate: [16, 16, 40],
            expert: [30, 16, 99]
        }
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
        @FLAG_COLOR = Gosu::Color.new(255, 0, 0)
        @NUMBER_COLOR_RANGE = [[50, 255, 50], [255, 50, 50]]
        @FONT = Gosu::Font.new(self, Gosu::default_font_name, @TILES_SIZE)
        @BIG_FONT = Gosu::Font.new(self, Gosu::default_font_name, @TILES_SIZE * 2)
        @SAFE_LANDING_RADIUS = 1
        restart
    end
    
    def restart
        @game_status = :ready
        @flags_count = 0
        @current_time = 0
        
        @mines_map = Array.new(@GRID_WIDTH).map{Array.new(@GRID_HEIGHT)}
        @proximity_map = Array.new(@GRID_WIDTH).map{Array.new(@GRID_HEIGHT)}
        @flags_map = Array.new(@GRID_WIDTH).map{Array.new(@GRID_HEIGHT).fill(false)}
    end

    def gen_map spawn_x, spawn_y
        #create array
        @MINES_COUNT.times do
            loop do
                x = rand @GRID_WIDTH
                y = rand @GRID_HEIGHT
                next if @mines_map[x][y] || (x.between?(spawn_x-@SAFE_LANDING_RADIUS, spawn_x+@SAFE_LANDING_RADIUS) && y.between?(spawn_y-@SAFE_LANDING_RADIUS, spawn_y+@SAFE_LANDING_RADIUS))
                @mines_map[x][y] = :mine
                break
            end
        end
        #proximity map
        @GRID_WIDTH.times do |x|
            @GRID_HEIGHT.times do |y|
                rel_count = 0
                3.times do |x_off|
                    x_pos = x + x_off - 1
                    next unless x_pos.between? 0, @GRID_WIDTH-1
                    3.times do |y_off|
                        y_pos = y + y_off - 1
                        next unless y_pos.between? 0, @GRID_WIDTH-1
                        tile = @mines_map[x_pos][y_pos]
                        rel_count+=1 if tile && tile == :mine
                    end
                end
                @proximity_map[x][y] = rel_count
            end
        end
    end

    def update
        @current_time = (((Time.now - @start_timestamp) *10).floor)/10.0 if @game_status == :playing
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
                @FONT.draw_text(@proximity_map[x][y], x_pos + @TILES_SIZE/4, y_pos + 2, 0, 1, 1, Gosu::Color.new(
                    (@NUMBER_COLOR_RANGE[1][0] - @NUMBER_COLOR_RANGE[0][0])*(@proximity_map[x][y]/8.0) + @NUMBER_COLOR_RANGE[0][0],
                    (@NUMBER_COLOR_RANGE[1][1] - @NUMBER_COLOR_RANGE[0][1])*(@proximity_map[x][y]/8.0) + @NUMBER_COLOR_RANGE[0][1],
                    (@NUMBER_COLOR_RANGE[1][2] - @NUMBER_COLOR_RANGE[0][2])*(@proximity_map[x][y]/8.0) + @NUMBER_COLOR_RANGE[0][2],
                )) if @proximity_map[x][y] && tile_type == :clear && @proximity_map[x][y] != 0

                #flag
                @FONT.draw_text("🚩F", x_pos + @TILES_SIZE / 4, y_pos + 2, 0, 1, 1, @FLAG_COLOR) if @flags_map[x][y] && (tile_type == :default || @game_status == :lost)
            end
        end
        #info
        @FONT.draw_text("🚩F #{(@MINES_COUNT - @flags_count)}", self.width - @TILES_SIZE*4/2, 8, 0)
        @FONT.draw_text("#{@current_time}s", 10, 8, 0)
        
        @BIG_FONT.draw_text("PERDU! (f5)", 40, (@GRID_HEIGHT * (@TILES_SIZE + @TILES_SPACING))/2 - 30 + @TOP_OFFSET, 0, 1, 1, Gosu::Color.new(255, 0, 0)) if @game_status == :lost
        @BIG_FONT.draw_text("GAGNÉ! (f5)", 40, (@GRID_HEIGHT * (@TILES_SIZE + @TILES_SPACING))/2 - 30 + @TOP_OFFSET, 0, 1, 1, Gosu::Color.new(0, 255, 0)) if @game_status == :won
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
        #restart click evt
        return restart unless @game_status == :playing || @game_status == :ready
        #tile events
        tile_x = (mouse_x / (@TILES_SIZE + @TILES_SPACING)).floor
        tile_y = ((mouse_y - @TOP_OFFSET) / (@TILES_SIZE + @TILES_SPACING)).floor
        # puts "x: #{tile_x}, y: #{tile_y}"
        return unless pos_in_map? tile_x, tile_y
        clear_tile(tile_x, tile_y) if key == Gosu::MsLeft
        toggle_flag(tile_x, tile_y) if key == Gosu::MsRight
    end
    def toggle_flag x, y
        return unless @game_status == :playing || @game_status == :ready
        return unless @mines_map[x][y] == nil || @mines_map[x][y] == :mine #Bricolo mondo
        @flags_map[x][y] = !@flags_map[x][y]
        @flags_count = get_count_in_array(@flags_map, true)
    end
    def clear_tile x, y
        if @game_status == :ready
            @start_timestamp = Time.now
            gen_map(x,y)
            @game_status = :playing
        end
        return unless @game_status == :playing
        return if @mines_map[x][y] == :clear
        return if @flags_map[x][y]
        return end_game if @mines_map[x][y] == :mine
        soft_clear x, y

        return end_game(:won) if (@GRID_WIDTH * @GRID_HEIGHT - get_count_in_array(@mines_map, :clear)) == @MINES_COUNT
    end
    def soft_clear x, y, should_reset_visited=true
        return unless pos_in_map? x, y
        @visited_map = Array.new(@GRID_WIDTH).map{Array.new(@GRID_HEIGHT).fill(false)} if should_reset_visited
        return if @visited_map[x][y]
        @visited_map[x][y] = true
        return if @mines_map[x][y] == :mine
        return if @flags_map[x][y]
        @mines_map[x][y] = :clear
        return if @proximity_map[x][y] > 0
        #exec on 3x3 area around
        3.times do |x_off|
            x_pos = x + x_off - 1
            3.times do |y_off|
                next if x_off == 1 && y_off == 1
                y_pos = y + y_off - 1
                soft_clear x_pos, y_pos, false
            end
        end
    end
    def pos_in_map? (x, y)
        x.between?(0, @GRID_WIDTH - 1) && y.between?(0, @GRID_HEIGHT - 1)
    end
    def end_game state = :lost
        @game_status = state
    end
    def get_count_in_array array, data_val
        array.reduce(0){|sum, data| sum + data.count(data_val)}
    end
end
MinesweeperTest.new.show