require 'date'

class CLI
  def run
    write_template(entry_path)

    Kernel.system("#{editor} \"#{entry_path}\"")

    delete_and_exit_if_empty_entry

    show_random_previous_entry
  end

  private

  def delete_and_exit_if_empty_entry
    entry_contents = File.read(entry_path)

    if entry_contents == entry_template
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

    date_and_time_str = Time.now.strftime('%Y-%m-%d__%H:%M:%S')
    @entry_path = "#{diary_path}/#{date_and_time_str}.md"
  end

  def entry_template
    return @entry_template if @entry_template

    done_todos = Todos.new.done_today
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

  def show_random_previous_entry
    random_entry_file_name = Dir.children(diary_path).sample
    random_entry_contents = File.
      readlines("#{diary_path}/#{random_entry_file_name}")

    entry_date_and_time = DateTime.parse(
      random_entry_file_name.
        gsub('__', ' ').
        gsub(/\.md\z/, '')
    )
    formatted_date = entry_date_and_time.strftime('%A, %F W%V')

    $stdout.puts(formatted_date)
    $stdout.puts
    $stdout.puts("---")
    $stdout.puts
    $stdout.puts(random_entry_contents)
  end

  def write_template(path)
    File.open(path, 'w') { |file| file.puts(entry_template) }
  end
end

class Todos
  TODO = Struct.new(:date_of_completion, :text, keyword_init: true) do
    def to_s
      text
    end
  end

  def done_today
    done_todos.select { |todo| todo.date_of_completion == Date.today }
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
