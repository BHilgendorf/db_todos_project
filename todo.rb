require 'sinatra'
require 'sinatra/content_for'
require 'tilt/erubis'

require_relative "database_persistence"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload "database_persistence.rb"
end

helpers do
  def todos_count(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].count { |todo| !todo[:completed]}
  end

  def list_complete?(list)
    todos_remaining_count(list) == 0 && todos_count(list) > 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def sort_todos(todos, &block)
      complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed]}

      incomplete_todos.each(&block)
      complete_todos.each(&block)
  end

  def sort_lists(lists, &block)
      complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }

      incomplete_lists.each(&block)
      complete_lists.each(&block)
  end
end

  def load_list(list_id)
    list = @storage.find_list(list_id)
    return list if list

    session[:error] = "The specified list was not found."
    redirect '/lists'
  end

  # Return an error message if list name is invalid. Return nil if valid
def error_for_list_name(name)
  if @storage.all_lists.any? { |list| list[:name] == name }
    'List name must be unique.'
  elsif !(1..100).cover?(name.size)
    'List name must be between 1 and 100 characters.'
  end
end

# Return error message if item name is invalid. Return nil if valid
def error_for_todo(name)
  if !(1..100).cover?(name.size)
    'Todo name must be between 1 and 100 characters.'
  end
end

# Increment todo 
def next_todo_id(todos)
  max = todos.map { |todo| todo[:id]}.max || 0
  max + 1
end


before do
  @storage = DatabasePersistence.new(logger)
end

get "/" do
  redirect "/lists"
end

# View all lists
get "/lists" do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# View Single todo list
get "/lists/:id" do
  list_id = params[:id].to_i
  @list = load_list(list_id)
  erb :list, layout: :layout
end

# Edit an existing todo list
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = load_list(id)
  erb :edit_list, layout: :layout
end

# Updating existing todo list
post "/lists/:list_id" do

  list_id = params[:list_id].to_i
  @list = load_list(list_id)
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @storage.update_list_name(list_id, list_name)
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{list_id}"
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

   error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_new_list(list_name)

    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Delete a List
post "/lists/:list_id/delete" do
  list_id = params[:list_id].to_i

  @storage.delete_list(list_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = 'The list has been deleted.'
    redirect '/lists'
  end
end

# Add todo to a List
post "/lists/:list_id/todos" do
  list_id = params[:list_id].to_i
  @list = load_list(list_id)
  todo_name = params[:todo].strip
  error = error_for_todo(todo_name)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @storage.create_new_todo(list_id, todo_name)

    session[:success] = 'The item was added to the list.'
    redirect "/lists/#{list_id}"
  end
end

# Delete a todo item
post "/lists/:list_id/delete/:item" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:item].to_i

  @storage.delete_todo_from_list(@list_id, todo_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = 'The item was delete from the list.'
    redirect "/lists/#{@list_id}"
  end
end

# Update status of todo item
post "/lists/:list_id/complete/:item" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:item].to_i
  new_status = params[:completed]
  @storage.update_todo_status(@list_id, todo_id,new_status)

  session[:success] = 'The item was updated.'
  redirect "/lists/#{@list_id}"
end

# Complete all items in list
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  item_id = params[:item].to_i

  @storage.mark_all_todos_as_completed(@list_id)
  
  session[:success] = 'All items have been marked completed.'
  redirect "/lists/#{@list_id}"
end