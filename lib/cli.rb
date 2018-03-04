class CLI
  def run
    write_template(entry_path)

    Kernel.system("#{editor} \"#{entry_path}\"")

    delete_if_empty_entry
    exit 0
  end

  private

  def delete_if_empty_entry
    entry_contents = File.read(entry_path)
    if entry_contents == entry_template
      $stdout.puts 'Empty entry: deleting'
      File.delete(entry_path)
    end
  end

  def editor
    @editor ||= fetch_from_env!('EDITOR')
  end

  def entry_path
    return @entry_path if @entry_path

    diary_path = fetch_from_env!('DIARY_PATH')
    date_and_time_str = Time.now.strftime('%Y-%m-%d__%H:%M:%S')
    @entry_path = "#{File.expand_path(diary_path)}/#{date_and_time_str}.md"
  end

  def entry_template
    <<~EOF


      ### Tags

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

  def write_template(path)
    File.open(path, 'w') { |file| file.puts(entry_template) }
  end
end
