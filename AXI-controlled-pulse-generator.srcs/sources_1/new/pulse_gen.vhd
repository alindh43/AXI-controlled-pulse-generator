----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Anton Lind
-- 
-- Create Date: 02/03/2026 10:17:07 AM
-- Design Name: 
-- Module Name: pulse_gen - rtl
-- Project Name: AXI-controlled-pulse-generator
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity pulse_gen is
--  Port ( );
    port(
        clk             : in std_logic;             -- system clock (50 MHz, 20ns cycle)                     
        rst_n           : in std_logic;             -- synchronous reset (active low)
        start           : in std_logic;             -- start pulse sequence
        pulse_width_i   : unsigned(3 downto 0);     -- number of cycles output is HIGH
        pri_i           : unsigned(3 downto 0);     -- total cycles per pulse
        burst_len_i     : unsigned(3 downto 0);     -- number of pulses
        pulse_out       : out std_logic             -- digital pulse signal
        );
end pulse_gen;



architecture rtl of pulse_gen is
    
    type t_state is (IDLE, LOAD, PULSE_HIGH, PULSE_LOW, FINISHED);
    
    signal State : t_state;
    
    signal width_cnt  : unsigned(3 downto 0);
    signal pri_cnt    : unsigned(3 downto 0);
    signal burst_cnt  : unsigned(3 downto 0);
    signal width_reg  : unsigned(3 downto 0);
    signal pri_reg    : unsigned(3 downto 0);     -- Total pulse period = pri_reg
    signal burst_reg  : unsigned(3 downto 0);
    
    signal busy : std_logic;
    signal busy_reg : std_logic;
    signal done : std_logic;
    signal done_reg :std_logic;
    signal pulse_out_reg : std_logic;
    
begin

p_state_machine : process(clk)
begin
    if rising_edge(clk) then
        if rst_n= '0' then
            width_cnt <= (others => '0');
            pri_cnt <= (others => '0');
            burst_cnt <= (others => '0');
            pulse_out_reg <= '0';
            busy_reg <= '0';
            done_reg <= '0';
            State <= Idle;
        else
            
            --------------------------------------------------------------
            --STATE MACHINE
            --------------------------------------------------------------
            case State is
                ------------------------- IDLE ------------------------------
                -- waiting for start
                when IDLE =>
                    pulse_out_reg <= '0';
                    busy_reg <= '0';
                    done_reg <= '0';
                    if start = '1' then 
                        State <= LOAD;
                    end if;
                --------------------------------------------------------------        
                        
                        
                ------------------------- LOAD --------------------------------
                -- latch parameters, clear counters
                when LOAD =>
                    
                    pulse_out_reg <= '0';
                    busy_reg <= '1';
                    done_reg <= '0';
                    
                    width_reg <= pulse_width_i;
                    pri_reg   <= pri_i;
                    burst_reg <= burst_len_i;
                    
                    width_cnt <= "0000";
                    pri_cnt   <= "0000";
                    burst_cnt <= "0000";
                    
                    if width_reg >= pri_reg then
                        State <= FINISHED;
                    else
                        State <= PULSE_HIGH;
                    end if;                                                        
                --------------------------------------------------------------
                    
                    
                ---------------------- PULSE HIGH ----------------------------   
                -- output high, count width            
                when PULSE_HIGH =>
                    pulse_out_reg <= '1';
                    busy_reg <= '1';
                    done_reg <= '0';
                 
                    if width_cnt = width_reg-1 then
                        width_cnt <= "0000";
                        State <= PULSE_LOW;
                    else
                        width_cnt <= width_cnt + 1;
                    end if;
                --------------------------------------------------------------
                
                    
                ---------------------- PULSE LOW -----------------------------  
                -- output low, count remainder of PRI    
                when PULSE_LOW =>
                    pulse_out_reg <= '0';
                    busy_reg <= '1';
                    done_reg <= '0';
                                   
                    if pri_cnt = (pri_reg - width_reg - 1) then
                        pri_cnt <= "0000";
                        burst_cnt <= burst_cnt + 1;
                        if burst_cnt = burst_reg - 1 then
                            State <= FINISHED;
                        else
                            State <= PULSE_HIGH;
                        end if;
                    else
                        pri_cnt <= pri_cnt + 1;
                    end if;
                --------------------------------------------------------------      
                
                        
                ---------------------- FINISHED ----------------------------------          
                -- burst finished, wait for clear
                when FINISHED =>
                    pulse_out_reg <= '0';
                    busy_reg <= '0';
                    done_reg <= '1';
                    
                    if start = '0' then
                        done_reg <= '0';
                        State <= IDLE;
                    end if;
                --------------------------------------------------------------
            end case;
        end if;
    end if;
end process;

pulse_out <= pulse_out_reg;
busy <= busy_reg;
done <= done_reg;

end rtl;
