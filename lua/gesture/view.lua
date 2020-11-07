local repository = require("gesture/lib/repository")
local windowlib = require("gesture/lib/window")
local Point = require("gesture/point").Point
local Canvas = require("gesture/view/canvas").Canvas
local GestureBoard = require("gesture/view/board").GestureBoard

local vim = vim

local M = {}

local View = {}
View.__index = View
M.View = View

function View.current_point()
  local x = vim.fn.wincol()
  local y = vim.fn.winline()
  return Point.new(x, y)
end

function View.focus(self, last_point)
  M.click()

  if not vim.api.nvim_win_is_valid(self.window_id) then
    return
  end

  local point = self.current_point()
  local last = self._new_points[#self._new_points] or last_point
  self._new_points = last:interpolate(point)

  return point
end

function View.close(self)
  vim.o.virtualedit = self._virtualedit
  repository.delete(self.window_id)
  windowlib.close(self.window_id)
end

function View.open()
  local bufnr = vim.api.nvim_create_buf(false, true)

  local width = vim.o.columns
  local height = vim.o.lines

  local window_id = vim.api.nvim_open_win(bufnr, true, {
    width = width,
    height = height,
    relative = "editor",
    row = 0,
    col = 0,
    external = false,
    style = "minimal",
  })
  vim.api.nvim_win_set_option(window_id, "winblend", 100)

  local lines = vim.fn["repeat"]({""}, height)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "filetype", "gesture")
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  local before_window_id = windowlib.by_pattern("^gesture://")
  if before_window_id ~= nil then
    M.close(before_window_id)
  end
  vim.api.nvim_buf_set_name(bufnr, ("gesture://%d/GESTURE"):format(bufnr))

  vim.api.nvim_win_set_option(window_id, "scrolloff", 0)
  vim.api.nvim_win_set_option(window_id, "sidescrolloff", 0)

  local virtualedit = vim.o.virtualedit
  vim.api.nvim_set_option("virtualedit", "all")

  -- NOTE: show and move cursor to the window by <LeftDrag>
  vim.api.nvim_command("redraw")
  M.click()

  local on_leave = ("autocmd WinLeave,TabLeave,BufLeave <buffer=%s> ++once lua require 'gesture/view'.close(%s)"):format(bufnr, window_id)
  vim.api.nvim_command(on_leave)

  local tbl = {
    window_id = window_id,
    _virtualedit = virtualedit,
    _canvas = Canvas.new(bufnr),
    _new_points = {},
  }
  return setmetatable(tbl, View)
end

M.close = function(window_id)
  local state = repository.get(window_id)
  if state == nil then
    return
  end
  state.view:close()
end

function View.render_input(self, inputs, gesture, has_forward_match)
  local board = GestureBoard.create(inputs, gesture, has_forward_match)
  self._canvas:draw(board, self._new_points)
end

local mouse = vim.api.nvim_eval("\"\\<LeftMouse>\"")
-- replace on testing
M.click = function()
  vim.api.nvim_command("normal! " .. mouse)
end

return M
