require 'date'
require 'time'
require 'tempfile'

class CLI
  def run
    if ARGV[0] == 'show' && ARGV[1]
      date = parse_date(ARGV[1])

      show_day_in_pager(date)
    else
      write_template

      Kernel.system("#{editor} \"#{entry_path}\"")

      remove_todo_list_at_bottom
      delete_and_exit_if_empty_entry

      show_random_previous_day_in_pager
    end
  end

  private

  def parse_date(date)
    if date == 'today'
      Date.today
    elsif date == 'yesterday'
      Date.today - 1
    else
      Date.parse(date)
    end
  end

  def delete_and_exit_if_empty_entry
    if File.readlines(entry_path).all? { |line| line.match?(/\A\s*\z/) }
      $stdout.puts 'Empty entry: deleting'
      File.delete(entry_path)
      exit 0
    end
  end

  def diary_path
    @diary_path ||= File.expand_path(fetch_from_env!('DIARY_PATH'))
  end

  def editor
    @editor ||= fetch_from_env!('EDITOR')
  end

  def entry_path
    return @entry_path if @entry_path

    date_and_time_str = entry_time.strftime('%Y-%m-%d__%H:%M:%S')
    @entry_path = "#{diary_path}/#{date_and_time_str}.md"
  end

  def entry_time
    if ARGV[0] == 'yesterday'
      full_day_in_seconds = 24*60*60
      Time.parse('23:00') - full_day_in_seconds
    elsif ARGV[0]
      Time.parse(ARGV[0])
    else
      Time.now
    end
  end

  def entry_template
    return @entry_template if @entry_template

    done_todos = Todos.new.done_for(entry_time.to_date)
    todo_lines = done_todos.map { |todo| "* #{todo}" }.join("\n")

    @entry_template = <<~EOF


      ### Done tasks

      #{todo_lines}
    EOF
  end

  def fetch_from_env!(var_name)
    var = ENV[var_name]

    unless var
      $stdout.puts "#{var_name} must be set"
      exit 1
    end

    var
  end

  def diary_pager
    @pager ||= fetch_from_env!('DIARY_PAGER')
  end

  def show_day_in_pager(date)
    diary_file_names = Dir.children(diary_path)
    entry = Struct.new(:file_name, :diary_path) do
      def entry_contents
        File.read(full_entry_path).chomp
      end

      def full_entry_path
        "#{diary_path}/#{file_name}"
      end

      def to_date
        Date.parse(file_name.gsub('__', ' ').gsub(/\.md\z/, ''))
      end

      def to_datetime
        DateTime.parse(file_name.gsub('__', ' ').gsub(/\.md\z/, ''))
      end
    end

    entries = diary_file_names.map do |file_name|
      entry.new(file_name, diary_path)
    end

    all_entries_from_date = entries.
      select { |entry| entry.to_date == date }.
      sort_by(&:to_datetime)

    tempfile = Tempfile.new('diary')

    formatted_day = date.strftime('%A, %F W%V')
    tempfile.puts(formatted_day)
    tempfile.puts('=' * formatted_day.length)
    tempfile.puts

    all_entries_from_date.each do |entry_from_date|
      formatted_time = entry_from_date.to_datetime.strftime('%R')

      tempfile.puts(formatted_time)
      tempfile.puts('-' * formatted_time.length)
      tempfile.puts
      tempfile.puts(entry_from_date.entry_contents)
      tempfile.puts
    end

    tempfile.puts('### Done tasks')
    tempfile.puts
    Todos.new.done_for(date).each do |todo|
      tempfile.puts("* #{todo}")
    end

    tempfile.close

    Kernel.system("#{diary_pager} #{tempfile.path}")

    tempfile.delete
  end

  def show_random_previous_day_in_pager
    diary_file_names = Dir.children(diary_path)
    entry = Struct.new(:file_name, :diary_path) do
      def entry_contents
        File.read(full_entry_path).chomp
      end

      def full_entry_path
        "#{diary_path}/#{file_name}"
      end

      def to_date
        Date.parse(file_name.gsub('__', ' ').gsub(/\.md\z/, ''))
      end

      def to_datetime
        DateTime.parse(file_name.gsub('__', ' ').gsub(/\.md\z/, ''))
      end
    end

    entries = diary_file_names.map do |file_name|
      entry.new(file_name, diary_path)
    end

    random_day = entries.
      map(&:to_date).
      uniq.
      reject { |date| date == entry_time.to_date }.
      sample
    all_entries_from_random_day = entries.select do |entry|
      entry.to_date == random_day
    end.sort_by(&:to_datetime)

    tempfile = Tempfile.new('diary')

    formatted_day = random_day.strftime('%A, %F W%V')
    tempfile.puts(formatted_day)
    tempfile.puts('=' * formatted_day.length)
    tempfile.puts

    all_entries_from_random_day.each do |entry|
      formatted_time = entry.to_datetime.strftime('%R')

      tempfile.puts(formatted_time)
      tempfile.puts('-' * formatted_time.length)
      tempfile.puts
      tempfile.puts(entry.entry_contents)
      tempfile.puts
    end

    tempfile.puts('### Done tasks')
    tempfile.puts
    Todos.new.done_for(random_day).each do |todo|
      tempfile.puts("* #{todo}")
    end

    tempfile.close

    Kernel.system("#{diary_pager} #{tempfile.path}")

    tempfile.delete
  end

  def remove_todo_list_at_bottom
    lines_until_todo_list = File.readlines(entry_path).take_while do |line|
      !line.start_with?('### Done tasks')
    end.join.chomp

    File.open(entry_path, 'w') { |file| file.puts(lines_until_todo_list) }
  end

  def write_template
    File.open(entry_path, 'w') { |file| file.puts(entry_template) }
  end
end

class Todos
  TODO = Struct.new(:date_of_completion, :text, keyword_init: true) do
    def to_s
      text
    end
  end

  def done_for(date)
    done_todos.select { |todo| todo.date_of_completion == date }
  end

  private

  def done_todos
    all_todos_output = `todo.sh -p listall`
    done_todo_lines = all_todos_output.lines(chomp: true).select do |line|
      line.start_with?(/\d+ x /)
    end

    done_todo_lines.map do |todo_line|
      line_without_number_and_completion_char = todo_line.gsub(/\A\d+ x /, '')
      date_of_completion = line_without_number_and_completion_char.
        split(' ').first

      todo_without_dates = line_without_number_and_completion_char.
        gsub(/\A(\d{4}-\d{2}-\d{2} ){2}(\{\d{4}.\d{2}.\d{2}\} )?/, '')

      TODO.new(
        date_of_completion: Date.parse(date_of_completion),
        text: todo_without_dates
      )
    end
  end
end
