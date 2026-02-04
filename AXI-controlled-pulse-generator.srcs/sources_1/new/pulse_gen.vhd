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
        clk                 : in std_logic;     -- System clock (50 MHz, 20ns cycle)                     
        rst_n               : in std_logic;     -- Synchronous reset (active low)
        start               : in std_logic;     -- Start flag from software to start pulse sequence
        pulse_high_time_i   : integer;          -- Pulse width (HIGH time). Number of cycles output is HIGH. Ex: 500 × 20 ns = 10 µs
        pulse_period_i      : integer;          -- Total pulse period, total cycles per pulse (total period). Ex 1000 × 20 ns = 20 µs
        bursts_i            : integer;          -- Number of pulses. Ex: 4.
        pulse_out           : out std_logic     -- Digital pulse signal
        );
end pulse_gen;



architecture rtl of pulse_gen is
    
    type t_state is (IDLE, LOAD, PULSE_HIGH, PULSE_LOW, FINISHED);
    
    signal State : t_state;
    
    signal high_cnt             : integer; -- Tracks how many clock cycles have been HIGH in this pulse. Incremetns once per clock
    signal pulse_high_time_reg  : integer; -- Input register
    
    signal period_cnt           : integer; -- Tracks how many LOW cycles have elapsed since the HIGH phase ended
    signal pulse_period_reg     : integer; -- Input register
    
    signal burst_cnt            : integer; -- Tracks how many pulses have been completed so far
    signal burst_reg            : integer; -- Input register

    signal busy          : std_logic;      -- Busy flag
    signal busy_reg      : std_logic;
    
    signal done          : std_logic;      -- Done flag
    signal done_reg      : std_logic;
    
    signal pulse_out_reg : std_logic;      -- Output register
    
begin

p_state_machine : process(clk)
begin
    if rising_edge(clk) then
        if rst_n= '0' then
            -- Updating registers
            pulse_out_reg <= '0';
            busy_reg <= '0';
            done_reg <= '0';
            -- Reset counters
            high_cnt <= 0;
            period_cnt <= 0;
            burst_cnt <= 0;
            -- Go to IDLE state
            State <= IDLE;
        else
            
            --------------------------------------------------------------
            --STATE MACHINE
            --------------------------------------------------------------
            case State is
            
                ------------------------- IDLE ------------------------------
                -- Waiting for start from software
                when IDLE =>
                    pulse_out_reg <= '0';
                    busy_reg <= '0';
                    done_reg <= '0';
                    if start = '1' then 
                        State <= LOAD;
                    end if;
                --------------------------------------------------------------        
                        
                        
                ------------------------- LOAD --------------------------------
                -- Latch software parameters, clear counters, rejecting invalid config
                when LOAD =>
                    
                    -- Updating registers
                    pulse_out_reg <= '0';
                    busy_reg <= '1';
                    done_reg <= '0';
                    
                    -- Latching software parameter (inputs)
                    pulse_high_time_reg <= pulse_high_time_i;
                    pulse_period_reg   <= pulse_period_i;
                    burst_reg <= bursts_i;
                    
                    -- Reset counters
                    high_cnt <= 0;
                    period_cnt   <= 0;
                    burst_cnt <= 0;
                    
                    -- Rejecting invalid config
                    if pulse_high_time_i >= pulse_period_i then
                        State <= FINISHED;
                    else
                        State <= PULSE_HIGH;
                    end if;                                                        
                --------------------------------------------------------------
                    
                    
                ---------------------- PULSE HIGH ----------------------------   
                -- Output high, count pulse high width            
                when PULSE_HIGH =>
                    pulse_out_reg <= '1';
                    busy_reg <= '1';
                    done_reg <= '0';
                    
                    if high_cnt = pulse_high_time_reg-1 then
                        high_cnt <= 0;
                        State <= PULSE_LOW;
                    else
                        high_cnt <= high_cnt + 1;
                    end if;
                --------------------------------------------------------------
                
                    
                ---------------------- PULSE LOW -----------------------------  
                -- output low, count remainder of pulse width    
                when PULSE_LOW =>
                    pulse_out_reg <= '0';
                    busy_reg <= '1';
                    done_reg <= '0';
                    
                               
                    if period_cnt = (pulse_period_reg - pulse_high_time_reg - 1) then
                         -- HIGH cycles = pulse_high_time_reg, so LOW cycles = pulse_period_reg - pulse_high_time_reg. Counter starts at 0, so -1   
                        period_cnt <= 0;
                        -- Pulse completed --> burt_cnt++
                        burst_cnt <= burst_cnt + 1;
                        if burst_cnt = burst_reg - 1 then
                            -- Needed number of pulses has been reached
                            State <= FINISHED;
                        else
                            State <= PULSE_HIGH;
                        end if;
                    else
                        period_cnt <= period_cnt + 1;
                    end if;
                --------------------------------------------------------------      
                
                        
                ---------------------- FINISHED ----------------------------------          
                -- burst finished, wait for clear
                when FINISHED =>
                    pulse_out_reg <= '0';
                    busy_reg <= '0';
                    done_reg <= '1';
                    
                    -- Handshake to confirm that start flag is 0 and can go back to IDLE state
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
